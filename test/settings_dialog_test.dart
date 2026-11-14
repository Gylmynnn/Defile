import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/settings_dialog.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/frb_generated.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _EmptyFs extends FileSystemService {
  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async =>
      const <rust.FileEntry>[];
}

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        'build/linux/x64/debug/bundle/lib/librust_lib_defile.so',
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets(
    'SettingsDialog Defile layout renders matching sections and items',
    (tester) async {
      Get.put(IconThemeService());
      Get.put(FontService());
      Get.put(ThemeService());

      final iconService = Get.find<IconThemeService>();
      final fontService = Get.find<FontService>();

      await tester.runAsync(iconService.init);
      await tester.runAsync(fontService.init);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsDialog())),
      );

      // Sidebar Category Headers & menu items (appear both as item under Options and as section header)
      expect(find.text('Options'), findsOneWidget);

      // Sidebar items
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Interface'), findsOneWidget);
      expect(find.text('Files and links'), findsOneWidget);
      expect(find.text('Hotkeys'), findsOneWidget);
      expect(find.text('About'), findsWidgets);
      // Right Content default is About. The version now comes from pubspec
      // (package_info_plus) and stays at the loading placeholder in tests,
      // so match the prefix only.
      expect(find.textContaining('Version'), findsWidgets);
      expect(find.text('Check for updates'), findsOneWidget);
      expect(find.text('Read the changelog.'), findsOneWidget);

      // Switch to Hotkeys
      await tester.tap(find.text('Hotkeys'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Toggle sidebar'), findsOneWidget);
      expect(find.text('Ctrl + B'), findsNothing); // Parsed into keys
      expect(find.text('Ctrl'), findsWidgets);

      // Search settings filter in sidebar
      await tester.enterText(find.byType(TextField).first, 'files');
      await tester.pumpAndSettle();

      expect(find.text('Files and links'), findsOneWidget);
      expect(find.text('About'), findsNothing);

      // Reset search
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      expect(find.text('About'), findsWidgets);

      // Close button works
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Interface section exposes sort and hidden-file controls', (
    tester,
  ) async {
    Get.put(IconThemeService());
    Get.put(FontService());
    Get.put(ThemeService());

    final controller = Get.put(FileExplorerController(_EmptyFs()));
    await tester.runAsync(() => controller.loadDirectory('/'));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsDialog())),
    );

    await tester.tap(find.text('Interface'));
    await tester.pumpAndSettle();

    expect(find.text('Sort files by'), findsOneWidget);
    expect(find.text('Sort direction'), findsOneWidget);
    expect(find.text('Show hidden files'), findsOneWidget);

    // The section reflects (and drives) the shared controller state.
    controller.setSortField(ExplorerSortField.size);
    controller.setSortAscending(false);
    controller.toggleHiddenFiles();
    await tester.pumpAndSettle();

    expect(controller.sortField.value, ExplorerSortField.size);
    expect(controller.sortAscending.value, isFalse);
    expect(controller.showHidden.value, isFalse);
  });
}
