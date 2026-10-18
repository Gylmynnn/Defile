import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/settings_dialog.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        'build/linux/x64/debug/bundle/lib/librust_lib_defile.so',
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('SettingsDialog Obsidian layout renders matching sections and items', (
    tester,
  ) async {
    Get.put(IconThemeService());
    Get.put(FontService());

    final iconService = Get.find<IconThemeService>();
    final fontService = Get.find<FontService>();

    await tester.runAsync(iconService.init);
    await tester.runAsync(fontService.init);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: SettingsDialog()),
      ),
    );

    // Sidebar Category Headers & menu items (appear both as item under Options and as section header)
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Core plugins'), findsWidgets);
    expect(find.text('Community plugins'), findsWidgets);

    // Sidebar items
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Interface'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Files and links'), findsOneWidget);
    expect(find.text('Hotkeys'), findsOneWidget);
    expect(find.text('Backlinks'), findsOneWidget);
    // Right Content default is General
    expect(find.text('Version 1.14.4'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Automatic updates'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Commercial license'), findsOneWidget);
    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(
      find.text('Notify if startup takes longer than expected'),
      findsOneWidget,
    );

    // Switch to Hotkeys
    await tester.tap(find.text('Hotkeys'));
    await tester.pumpAndSettle();

    expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    expect(find.text('Toggle sidebar'), findsOneWidget);
    expect(find.text('Ctrl + B'), findsNothing); // Parsed into keys
    expect(find.text('Ctrl'), findsWidgets);

    // Search settings filter in sidebar
    await tester.enterText(find.byType(TextField).first, 'canvas');
    await tester.pumpAndSettle();

    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('General'), findsNothing);

    // Reset search
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    expect(find.text('General'), findsOneWidget);

    // Close button works
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
