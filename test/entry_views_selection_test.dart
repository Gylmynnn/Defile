import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/entry_views.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  setUp(() => Get.put(IconThemeService()));
  tearDown(Get.reset);

  testWidgets('grid tile highlight tracks selectedPaths reactively', (
    tester,
  ) async {
    final entry = rust.FileEntry(
      name: 'a.txt',
      path: '/a.txt',
      isDirectory: false,
      isFile: true,
      sizeBytes: BigInt.zero,
      modifiedSeconds: 0,
    );
    final RxSet<String> selected = <String>{}.obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryGridView(
            entries: [entry],
            selectedPaths: selected,
            onPress: (_) {},
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
          ),
        ),
      ),
    );

    Color tileColor() {
      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(entryTileKey(entry.path)),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(tileColor(), Colors.transparent);

    selected.add(entry.path);
    await tester.pumpAndSettle();

    expect(tileColor(), isNot(Colors.transparent));

    selected.clear();
    await tester.pumpAndSettle();

    expect(tileColor(), Colors.transparent);
  });

  testWidgets('dragging a selected group drops every entry on a folder', (
    tester,
    ) async {
    rust.FileEntry entry(String name, {bool isDirectory = false}) =>
        rust.FileEntry(
          name: name,
          path: '/$name',
          isDirectory: isDirectory,
          isFile: !isDirectory,
          sizeBytes: BigInt.zero,
          modifiedSeconds: 0,
        );

    final folder = entry('folder', isDirectory: true);
    final alpha = entry('alpha.txt');
    final beta = entry('beta.txt');
    final RxSet<String> selected = <String>{alpha.path, beta.path}.obs;

    List<rust.FileEntry> dragEntries(rust.FileEntry entry) =>
        selected.contains(entry.path) ? [alpha, beta] : [entry];

    List<rust.FileEntry>? dropped;
    String? destination;
    bool canDrop(List<rust.FileEntry> entries, String path) =>
        path == folder.path;

    // Mounting the grid exercises the native drag/drop widgets (DragItemWidget
    // + DropRegion) inside the test environment.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryGridView(
            entries: [folder, alpha, beta],
            selectedPaths: selected,
            onPress: (_) {},
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
            dragEntries: dragEntries,
            canDrop: canDrop,
            onDrop: (entries, path) {
              dropped = entries;
              destination = path;
            },
          ),
        ),
      ),
    );

    void onDrop(List<rust.FileEntry> entries, String path) {
      dropped = entries;
      destination = path;
    }

    // Native drag sessions cannot be driven from gesture tests, so verify the
    // payload round-trip the platform layer performs instead: drag payload
    // from the selection -> session localData -> reconstructed entries ->
    // accept + drop callbacks.
    Future<void> dragAndDrop(rust.FileEntry source) async {
      final DragItem? item = await buildEntryDragItem(dragEntries(source));
      expect(item, isNotNull);
      final entries = entriesFromLocalData(item!.localData);
      if (canDrop(entries, folder.path)) {
        onDrop(entries, folder.path);
      }
    }

    await dragAndDrop(alpha);
    expect(dropped?.map((entry) => entry.path), [alpha.path, beta.path]);
    expect(destination, folder.path);

    dropped = null;
    destination = null;
    selected.clear();
    await tester.pumpAndSettle();

    await dragAndDrop(alpha);
    expect(dropped?.map((entry) => entry.path), [alpha.path]);

    // Empty selection cancels the drag before it starts.
    expect(await buildEntryDragItem(const []), isNull);
  });
}
