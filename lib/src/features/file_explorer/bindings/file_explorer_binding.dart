import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:get/get.dart';

class FileExplorerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FileSystemService>(() => FileSystemService());

    Get.lazyPut<FileExplorerController>(
      () => FileExplorerController(Get.find<FileSystemService>()),
    );
  }
}
