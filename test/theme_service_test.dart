import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:defile/src/theme/app_theme.dart';
import 'package:defile/src/theme/theme_palette.dart';
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

  testWidgets('ThemeService applies the base color theme and accent color', (
    tester,
  ) async {
    Get.put(ThemeService());
    final service = Get.find<ThemeService>();

    await tester.runAsync(service.init);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark(), home: const SizedBox.shrink()),
    );

    await tester.runAsync(() => service.setBaseTheme('gruvbox'));
    await tester.pumpAndSettle();
    expect(service.baseThemeId.value, 'gruvbox');
    expect(service.palette.id, AppPalettes.gruvbox.id);
    expect(AppColors.window, AppPalettes.gruvbox.window);

    await tester.runAsync(() => service.setBaseTheme('everblush'));
    await tester.pumpAndSettle();
    expect(AppColors.window, AppPalettes.everblush.window);

    await tester.runAsync(() => service.setAccent('blue'));
    await tester.pumpAndSettle();
    expect(service.accentId.value, 'blue');
    expect(AppColors.accent, AppAccents.blue.color);

    // Reset back to the default settings.
    await tester.runAsync(
      () => service.setBaseTheme(AppPalettes.obsidianDark.id),
    );
    await tester.runAsync(() => service.setAccent(AppAccents.amber.id));
    expect(AppColors.window, AppPalettes.obsidianDark.window);
    expect(AppColors.accent, AppAccents.amber.color);

    service.setUiScale(1.25);
    await tester.pumpAndSettle();
    expect(service.uiScale.value, 1.25);

    service.setUiScale(1.0);
    await tester.pumpAndSettle();
    expect(service.uiScale.value, 1.0);
  });
}
