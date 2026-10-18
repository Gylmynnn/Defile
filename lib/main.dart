import 'package:defile/src/features/file_explorer/bindings/file_explorer_binding.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/views/file_explorer_page.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:defile/src/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await windowManager.ensureInitialized();

  final fontService = Get.put(FontService());
  await fontService.init();

  final themeService = Get.put(ThemeService());
  await themeService.init();

  final windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final FontService fontService = Get.find<FontService>();
    final ThemeService themeService = Get.find<ThemeService>();

    return Obx(() {
      final String font = fontService.fontFamily.value;

      AppColors.usePalette(themeService.palette);
      AppColors.useAccent(themeService.accent);

      return GetMaterialApp(
        title: 'Defile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(fontFamily: font.isEmpty ? null : font),
        initialBinding: FileExplorerBinding(),
        builder: (context, child) => Obx(
          () => _UiScaler(
            scale: themeService.uiScale.value,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: Obx(() {
          themeService.baseThemeId.value;
          themeService.accentId.value;
          return FileExplorerPage();
        }),
      );
    });
  }
}

/// Scales the whole application surface so the interface can be enlarged or
/// shrunk like a display/monitor scale setting.
class _UiScaler extends StatelessWidget {
  const _UiScaler({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1.0).abs() < 0.001) {
      return child;
    }

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size logicalSize = mediaQuery.size / scale;

    return MediaQuery(
      data: mediaQuery.copyWith(size: logicalSize),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: logicalSize.width,
            height: logicalSize.height,
            child: child,
          ),
        ),
      ),
    );
  }
}
