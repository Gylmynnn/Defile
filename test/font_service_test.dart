import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
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

  testWidgets('FontService loads the system font list and updates the theme', (
    tester,
  ) async {
    Get.put(FontService());
    final service = Get.find<FontService>();

    await tester.runAsync(service.init);

    final String originalFont = service.fontFamily.value;
    addTearDown(() => tester.runAsync(() => service.setFont(originalFont)));

    expect(service.fonts, isNotEmpty);

    await tester.runAsync(() => service.setFont('DejaVu Sans'));
    expect(service.fontFamily.value, 'DejaVu Sans');

    await tester.runAsync(() => service.setFont(''));
    expect(service.fontFamily.value, '');
  });

  testWidgets('SettingsDialog has a System Font tab and can select a font', (
    tester,
  ) async {
    Get.put(IconThemeService());
    Get.put(FontService());
    Get.put(ThemeService());

    final iconService = Get.find<IconThemeService>();
    final fontService = Get.find<FontService>();

    await tester.runAsync(iconService.init);
    await tester.runAsync(fontService.init);

    final String originalFont = fontService.fontFamily.value;
    addTearDown(() => tester.runAsync(() => fontService.setFont(originalFont)));

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SettingsDialog())),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('About'), findsWidgets);

    // Default section is About
    expect(find.text('Version 0.5.0'), findsOneWidget);

    // Pindah ke section Appearance
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Display font'), findsOneWidget);
    expect(find.text('Application default'), findsWidgets);

    // Search for a font using the font search field
    final fontSearchFinder = find.widgetWithText(TextField, '');
    if (fontSearchFinder.evaluate().isNotEmpty) {
      await tester.enterText(fontSearchFinder.last, 'Sans');
      await tester.pumpAndSettle();

      await tester.enterText(fontSearchFinder.last, '');
      await tester.pumpAndSettle();
    }

    // Pick the first non-default font if any
    if (fontService.fonts.isNotEmpty) {
      final String firstFont = fontService.fonts.first;
      final target = find.text(firstFont);
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target.first);
        await tester.pumpAndSettle();

        expect(fontService.fontFamily.value, firstFont);
      }
    }

    // Reset back to default
    final defaultFontFinder = find.text('Application default').last;
    await tester.ensureVisible(defaultFontFinder);
    await tester.pumpAndSettle();
    await tester.tap(defaultFontFinder);
    await tester.pumpAndSettle();

    expect(fontService.fontFamily.value, '');
  });
}
