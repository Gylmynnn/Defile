import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../services/file_system_service.dart';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;

class DirectoryPickerController extends GetxController {
  DirectoryPickerController(this.fileSystemService);

  final FileSystemService fileSystemService;

  final RxString currentPath = ''.obs;
  final RxList<rust.FileEntry> directories = <rust.FileEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// Sidebar shortcuts (quick access, bookmarked folders, drives), loaded by
  /// the picker itself so the dialog stays self-contained.
  final RxList<rust_system.Place> places = <rust_system.Place>[].obs;

  Future<void> initialize(String initialPath) async {
    currentPath.value = initialPath;
    await loadDirectories();
    _loadPlaces(); // Not awaited: the list renders as soon as it arrives.
  }

  Future<void> loadDirectories() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final entries = await fileSystemService.listDirectory(currentPath.value);

      directories.assignAll(entries.where((entry) => entry.isDirectory));
    } catch (error) {
      directories.clear();
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  List<rust_system.Place> get homePlaces =>
      places.where((place) => place.kind == rust_system.PlaceKind.home).toList();

  List<rust_system.Place> get folderPlaces =>
      places.where((place) => place.kind == rust_system.PlaceKind.folder).toList();

  List<rust_system.Place> get drivePlaces =>
      places.where((place) => place.kind == rust_system.PlaceKind.drive).toList();

  /// Only real, browsable directories qualify as destinations, so locations
  /// like Recents, Trash or Network are excluded from the sidebar.
  static bool isDestination(rust_system.Place place) =>
      place.kind == rust_system.PlaceKind.home ||
      place.kind == rust_system.PlaceKind.folder ||
      place.kind == rust_system.PlaceKind.drive;

  bool isPlaceActive(rust_system.Place place) =>
      isDestination(place) &&
      place.path.isNotEmpty &&
      currentPath.value == place.path;

  void openPlace(rust_system.Place place) {
    if (!isDestination(place) || place.path.isEmpty) return;

    currentPath.value = place.path;
    loadDirectories();
  }

  Future<void> _loadPlaces() async {
    try {
      places.assignAll(await rust_system.listPlaces());
    } catch (_) {
      places.clear();
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
