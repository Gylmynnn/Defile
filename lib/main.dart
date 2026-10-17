import 'package:defile/src/features/file_explorer/bindings/file_explorer_binding.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
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

    return Obx(() {
      final String font = fontService.fontFamily.value;

      return GetMaterialApp(
        title: 'Defile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(fontFamily: font.isEmpty ? null : font),
        initialBinding: FileExplorerBinding(),
        home: const FileExplorerPage(),
      );
    });
  }
}
