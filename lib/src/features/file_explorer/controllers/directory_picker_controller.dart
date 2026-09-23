import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../services/file_system_service.dart';

import 'package:defile/src/rust/api/file_entry.dart' as rust;

class DirectoryPickerController extends GetxController {
  DirectoryPickerController(this.fileSystemService);

  final FileSystemService fileSystemService;

  final currentPath = ''.obs;
  final directories = <rust.FileEntry>[].obs;
  final isLoading = false.obs;

  Future<void> initialize(String initialPath) async {
    currentPath.value = initialPath;
    await loadDirectories();
  }

  Future<void> loadDirectories() async {
    isLoading.value = true;

    try {
      final entries = await fileSystemService.listDirectory(currentPath.value);

      directories.assignAll(entries.where((entry) => entry.isDirectory));
    } catch (error) {
      Get.snackbar('Gagal memuat folder', error.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openDirectory(rust.FileEntry entry) async {
    currentPath.value = entry.path;
    await loadDirectories();
  }

  Future<void> goToParent() async {
    final parent = p.dirname(currentPath.value);

    if (parent == currentPath.value) return;

    currentPath.value = parent;
    await loadDirectories();
  }

  bool get isRoot => p.dirname(currentPath.value) == currentPath.value;

  void selectCurrentDirectory() {
    Get.back<String>(result: currentPath.value);
  }
}
