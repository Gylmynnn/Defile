import 'package:defile/src/features/file_explorer/controllers/explorer_tabs_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:get/get.dart';

class FileExplorerBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<IconThemeService>()) {
      Get.put<IconThemeService>(IconThemeService()).init();
    }

    if (!Get.isRegistered<FontService>()) {
      Get.put<FontService>(FontService()).init();
    }

    if (!Get.isRegistered<ThemeService>()) {
      Get.put<ThemeService>(ThemeService()).init();
    }

    Get.lazyPut<FileSystemService>(() => FileSystemService());

    Get.lazyPut<ExplorerTabsController>(
      () => ExplorerTabsController(Get.find<FileSystemService>()),
    );
  }
}
