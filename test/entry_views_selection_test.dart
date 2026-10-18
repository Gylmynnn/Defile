import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/entry_views.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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
    await tester.pump();

    expect(tileColor(), isNot(Colors.transparent));

    selected.clear();
    await tester.pump();

    expect(tileColor(), Colors.transparent);
  });
}
