import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/entry_views.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

rust.FileEntry _entry(String name, String path, {bool directory = false}) =>
    rust.FileEntry(
      name: name,
      path: path,
      isDirectory: directory,
      isFile: !directory,
      sizeBytes: BigInt.zero,
      modifiedSeconds: 0,
    );

RxList<rust.FileEntry> _list(List<rust.FileEntry> entries) =>
    RxList<rust.FileEntry>(entries);

void main() {
  setUp(() => Get.put(IconThemeService()));
  tearDown(Get.reset);

  testWidgets('EntryColumnsView renders parent, current and preview panes', (
    tester,
  ) async {
    final RxSet<String> selected = <String>{}.obs;
    final List<rust.FileEntry> navigated = <rust.FileEntry>[];
    final List<rust.FileEntry> previewed = <rust.FileEntry>[];
    final List<rust.FileEntry> pressed = <rust.FileEntry>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryColumnsView(
            parentEntries: _list([_entry('b', '/b', directory: true)]),
            entries: [
              _entry('sub', '/b/sub', directory: true),
              _entry('note.txt', '/b/note.txt'),
            ],
            previewEntries: _list([_entry('deep.txt', '/b/sub/deep.txt')]),
            previewFile: Rxn<rust.FileEntry>(),
            selectedPaths: selected,
            currentPath: '/b',
            previewPath: RxString('/b/sub'),
            onPress: (entry) => pressed.add(entry),
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
            onNavigate: (entry) => navigated.add(entry),
            onPreview: (entry) => previewed.add(entry),
          ),
        ),
      ),
    );

    // Parent column shows the active folder, current column its entries and
    // the preview column the selected folder's contents.
    expect(find.text('b'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
    expect(find.text('note.txt'), findsOneWidget);
    expect(find.text('deep.txt'), findsOneWidget);

    // Pressing a row in the active column reports the entry (the gesture
    // pipeline itself is exercised by the real app).
    await tester.tap(find.text('note.txt'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(pressed.single.path, '/b/note.txt');
    expect(navigated, isEmpty);

    // Tapping a folder in the parent column navigates into it.
    await tester.tap(find.text('b'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(navigated.single.path, '/b');

    // Tapping a file in the preview column previews it instead of opening it.
    await tester.tap(find.text('deep.txt'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(previewed.single.path, '/b/sub/deep.txt');
    expect(
      navigated.map((entry) => entry.path),
      <String>['/b'],
    );
  });

  testWidgets('preview column reacts to the preview observable', (
    tester,
  ) async {
    final RxList<rust.FileEntry> preview = _list(const []);
    final RxString previewPath = RxString('');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryColumnsView(
            parentEntries: _list(const []),
            entries: [_entry('note.txt', '/b/note.txt')],
            previewEntries: preview,
            previewFile: Rxn<rust.FileEntry>(),
            selectedPaths: <String>{}.obs,
            currentPath: '/b',
            previewPath: previewPath,
            onPress: (_) {},
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
            onNavigate: (_) {},
            onPreview: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Select a folder'), findsOneWidget);

    previewPath.value = '/b/sub';
    preview.addAll([_entry('deep.txt', '/b/sub/deep.txt')]);
    await tester.pump();

    expect(find.text('Select a folder'), findsNothing);
    expect(find.text('deep.txt'), findsOneWidget);
  });

  testWidgets('preview column renders the selected file content', (
    tester,
  ) async {
    final Rxn<rust.FileEntry> previewFile = Rxn<rust.FileEntry>(
      _entry('report.zzz', '/b/report.zzz'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryColumnsView(
            parentEntries: _list(const []),
            entries: const <rust.FileEntry>[],
            previewEntries: _list(const []),
            previewFile: previewFile,
            selectedPaths: <String>{}.obs,
            currentPath: '/b',
            previewPath: RxString(''),
            onPress: (_) {},
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
            onNavigate: (_) {},
            onPreview: (_) {},
          ),
        ),
      ),
    );

    // The pane switches from the placeholder to the file's preview.
    expect(find.text('Select a folder'), findsNothing);
    expect(find.text('report.zzz'), findsOneWidget);
    expect(find.text('No preview available'), findsOneWidget);
  });

  testWidgets('EntryColumnsView highlights the active folder in the parent', (
    tester,
  ) async {
    final RxSet<String> selected = <String>{}.obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryColumnsView(
            parentEntries: _list([
              _entry('a', '/a', directory: true),
              _entry('b', '/b', directory: true),
            ]),
            entries: [_entry('note.txt', '/b/note.txt')],
            previewEntries: _list(const []),
            previewFile: Rxn<rust.FileEntry>(),
            selectedPaths: selected,
            currentPath: '/b',
            previewPath: RxString(''),
            onPress: (_) {},
            onTap: (_) {},
            onOpen: (_) {},
            onMenu: (entry, position) {},
            onNavigate: (_) {},
            onPreview: (_) {},
          ),
        ),
      ),
    );

    Color rowColor(String path) {
      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(entryTileKey(path)),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(rowColor('/b'), isNot(Colors.transparent));
    expect(rowColor('/a'), Colors.transparent);
  });
}
