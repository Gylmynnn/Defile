import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

class FileExplorerController extends GetxController {
  FileExplorerController(this.fileSystemService);

  final FileSystemService fileSystemService;

  final RxString currentPath = '/home/ligichi'.obs;
  final RxList<rust.FileEntry> entries = <rust.FileEntry>[].obs;

  final RxBool isLoading = false.obs;

  final RxnString errorMessage = RxnString();

  final RxList<String> pathHistory = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDirectory(currentPath.value);
  }

  Future<void> createDirectory(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      Get.snackbar(
        "Nama folder kosong",
        "Masukkan nama folder terlebih dahulu",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await fileSystemService.createDirectory(currentPath.value, trimmedName);
      await refreshDirectory();

      Get.snackbar(
        "Berhasil",
        'Folder "$trimmedName" berhasil dibuat',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Gagal membuat folder',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openDirectory(rust.FileEntry entry) async {
    if (!entry.isDirectory) return;
    pathHistory.add(currentPath.value);
    await loadDirectory(entry.path);
  }

  Future<void> goBack() async {
    if (pathHistory.isEmpty) return;
    final previousPath = pathHistory.removeLast();
    await loadDirectory(previousPath);
  }

  Future<void> goToParent() async {
    final parentPath = p.dirname(currentPath.value);

    if (parentPath == currentPath.value) return;

    pathHistory.add(currentPath.value);
    await loadDirectory(parentPath);
  }

  Future<void> refreshDirectory() async {
    await loadDirectory(currentPath.value);
  }

  Future<void> navigateTo(String path) async {
    if (path == currentPath.value) return;

    pathHistory.add(currentPath.value);
    await loadDirectory(path);
  }

  List<String> get breadcrumbs {
    final normalized = p.normalize(currentPath.value);
    final parts = p.split(normalized);

    final result = <String>[];
    var accumulatedPath = p.rootPrefix(normalized);

    for (final part in parts) {
      if (part == p.rootPrefix(normalized)) continue;

      accumulatedPath = p.join(accumulatedPath, part);
      result.add(accumulatedPath);
    }

    return result;
  }

  Future<void> loadDirectory(String path) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await fileSystemService.listDirectory(path);
      entries.assignAll(result);
      currentPath.value = path;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openFile(rust.FileEntry entry) async {
    if (entry.isDirectory) {
      await openDirectory(entry);
      return;
    }

    try {
      await fileSystemService.openFile(entry.path);
    } catch (error) {
      Get.snackbar(
        'Gagal membuka file',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
