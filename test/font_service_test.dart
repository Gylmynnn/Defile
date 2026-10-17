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

  testWidgets('FontService memuat list font sistem dan memperbarui tema', (
    tester,
  ) async {
    Get.put(FontService());
    final service = Get.find<FontService>();

    await tester.runAsync(service.init);

    expect(service.fonts, isNotEmpty);

    await tester.runAsync(() => service.setFont('DejaVu Sans'));
    expect(service.fontFamily.value, 'DejaVu Sans');

    await tester.runAsync(() => service.setFont(''));
    expect(service.fontFamily.value, '');
  });

  testWidgets('SettingsDialog memiliki tab Font Sistem dan bisa memilih font', (
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

    expect(find.text('Tema Ikon'), findsOneWidget);
    expect(find.text('Font Sistem'), findsOneWidget);

    // Default tab adalah Tema Ikon
    expect(find.text('Tema ikon'), findsOneWidget);

    // Pindah ke tab Font Sistem
    await tester.tap(find.text('Font Sistem'));
    await tester.pumpAndSettle();

    expect(find.text('Font tampilan'), findsOneWidget);
    expect(find.text('Bawaan aplikasi'), findsOneWidget);

    // Cari font
    await tester.enterText(find.byType(TextField), 'Sans');
    await tester.pumpAndSettle();

    // Reset pencarian
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    // Pilih font pertama selain bawaan jika ada
    if (fontService.fonts.isNotEmpty) {
      final String firstFont = fontService.fonts.first;
      final target = find.text(firstFont);
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target.first);
        await tester.pumpAndSettle();

        expect(fontService.fontFamily.value, firstFont);
      }
    }

    // Reset kembali ke bawaan
    await tester.tap(find.text('Bawaan aplikasi'));
    await tester.pumpAndSettle();

    expect(fontService.fontFamily.value, '');
  });
}
