import 'package:defile/src/features/file_explorer/controllers/explorer_tabs_controller.dart';
import 'package:defile/src/features/file_explorer/services/drive_service.dart';
import 'package:defile/src/features/file_explorer/services/favorites_service.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/services/window_controls_service.dart';
import 'package:get/get.dart';

class FileExplorerBinding extends Bindings {
  FileExplorerBinding({this.autoMountDrives = true});

  /// False for the hidden portal-backend process, which may list drives but
  /// must never mount devices behind the user's back.
  final bool autoMountDrives;

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

    if (!Get.isRegistered<WindowControlsService>()) {
      Get.put<WindowControlsService>(WindowControlsService()).init();
    }

    if (!Get.isRegistered<FavoritesService>()) {
      Get.put<FavoritesService>(FavoritesService()).init();
    }

    if (!Get.isRegistered<DriveService>()) {
      Get.put<DriveService>(
        DriveService(autoMountAllowed: autoMountDrives),
      );
    }

    Get.lazyPut<FileSystemService>(() => FileSystemService());

    Get.lazyPut<ExplorerTabsController>(
      () => ExplorerTabsController(Get.find<FileSystemService>()),
    );
  }
}
