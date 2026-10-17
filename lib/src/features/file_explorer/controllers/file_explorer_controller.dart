import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

enum ExplorerViewMode { grid, list, compact }

enum ExplorerLocation { directory, recent, trash }

class FileExplorerController extends GetxController {
  FileExplorerController(this.fileSystemService);

  final FileSystemService fileSystemService;

  final RxString homePath = ''.obs;
  final RxString currentPath = ''.obs;
  final RxList<rust.FileEntry> entries = <rust.FileEntry>[].obs;
  final RxList<rust_system.Place> places = <rust_system.Place>[].obs;
  final RxMap<String, rust_system.DiskUsage> driveUsages =
      <String, rust_system.DiskUsage>{}.obs;
  final Rxn<rust_system.DiskUsage> diskUsage = Rxn();

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final Rx<ExplorerLocation> location = ExplorerLocation.directory.obs;

  final Rx<ExplorerViewMode> viewMode = ExplorerViewMode.grid.obs;
  final RxBool showSidebar = true.obs;
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  final RxList<rust.FileEntry> selection = <rust.FileEntry>[].obs;
  final RxnString selectionAnchor = RxnString();
  final RxList<rust.FileEntry> clipboardEntries = <rust.FileEntry>[].obs;
  final RxBool clipboardIsCut = false.obs;

  final RxList<String> pathHistory = <String>[].obs;
  final RxList<String> forwardHistory = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      homePath.value = rust_system.getHomeDirectory();
    } catch (_) {
      homePath.value = '/';
    }

    await Future.wait([loadDirectory(homePath.value), _loadPlaces()]);
  }

  Future<void> _loadPlaces() async {
    try {
      places.assignAll(await rust_system.listPlaces());
    } catch (_) {
      places.clear();
    }

    for (final drive in drivePlaces) {
      try {
        driveUsages[drive.path] = await rust_system.getDiskUsage(
          path: drive.path,
        );
      } catch (_) {
        continue;
      }
    }
  }

  List<rust_system.Place> get quickPlaces => places
      .where(
        (place) =>
            place.kind != rust_system.PlaceKind.folder &&
            place.kind != rust_system.PlaceKind.drive,
      )
      .toList();

  List<rust_system.Place> get folderPlaces => places
      .where((place) => place.kind == rust_system.PlaceKind.folder)
      .toList();

  List<rust_system.Place> get drivePlaces => places
      .where((place) => place.kind == rust_system.PlaceKind.drive)
      .toList();

  bool isPlaceActive(rust_system.Place place) {
    switch (place.kind) {
      case rust_system.PlaceKind.recent:
        return location.value == ExplorerLocation.recent;
      case rust_system.PlaceKind.network:
        return false;
      case rust_system.PlaceKind.home:
        return location.value == ExplorerLocation.directory &&
            currentPath.value == homePath.value;
      case rust_system.PlaceKind.folder:
      case rust_system.PlaceKind.drive:
      case rust_system.PlaceKind.trash:
        return location.value == ExplorerLocation.directory &&
            place.path.isNotEmpty &&
            currentPath.value == place.path;
    }
  }

  List<rust.FileEntry> get visibleEntries {
    final String query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return entries;

    return entries
        .where((entry) => entry.name.toLowerCase().contains(query))
        .toList();
  }

  bool get canGoToParent =>
      location.value == ExplorerLocation.directory &&
      p.dirname(currentPath.value) != currentPath.value;

  String crumbLabel(String path) {
    if (path == homePath.value) return 'Home';

    final String base = p.basename(path);
    return base.isEmpty ? path : base;
  }

  List<String> get breadcrumbs {
    final String normalized = p.normalize(currentPath.value);
    final List<String> parts = p.split(normalized);

    final List<String> result = <String>[];
    String accumulatedPath = p.rootPrefix(normalized);

    for (final String part in parts) {
      if (part == p.rootPrefix(normalized)) continue;

      accumulatedPath = p.join(accumulatedPath, part);
      result.add(accumulatedPath);
    }

    return result;
  }

  Future<void> loadDirectory(String path) async {
    isLoading.value = true;
    errorMessage.value = null;
    location.value = ExplorerLocation.directory;
    clearSelection();

    try {
      final result = await fileSystemService.listDirectory(path);
      entries.assignAll(result);
      currentPath.value = path;
      _refreshDiskUsage(path);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshDiskUsage(String path) async {
    try {
      diskUsage.value = await rust_system.getDiskUsage(path: path);
    } catch (_) {
      diskUsage.value = null;
    }
  }

  Future<void> openPlace(rust_system.Place place) async {
    switch (place.kind) {
      case rust_system.PlaceKind.home:
      case rust_system.PlaceKind.folder:
      case rust_system.PlaceKind.drive:
        await navigateTo(place.path);
      case rust_system.PlaceKind.recent:
        await showRecent();
      case rust_system.PlaceKind.trash:
        await showTrash();
      case rust_system.PlaceKind.network:
        Get.snackbar(
          'Network',
          'Penjelajahan jaringan belum didukung.',
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  Future<void> showRecent() async {
    if (location.value == ExplorerLocation.recent) return;

    _pushCurrentToHistory();
    forwardHistory.clear();
    location.value = ExplorerLocation.recent;
    await _loadRecentEntries();
  }

  Future<void> _loadRecentEntries() async {
    isLoading.value = true;
    errorMessage.value = null;
    clearSelection();

    try {
      final result = await rust_system.listRecentFiles(
        root: homePath.value,
        limit: 100,
      );
      entries.assignAll(result);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> showTrash() async {
    rust_system.Place? trashPlace;
    for (final place in places) {
      if (place.kind == rust_system.PlaceKind.trash) {
        trashPlace = place;
        break;
      }
    }

    final String trashPath = trashPlace?.path ?? '';

    if (trashPath.isEmpty) {
      Get.snackbar(
        'Trash',
        'Trash tidak tersedia di platform ini.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await fileSystemService.listDirectory(trashPath);
    } catch (_) {
      Get.snackbar(
        'Trash',
        'Folder trash masih kosong.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await navigateTo(trashPath);
  }

  void _pushCurrentToHistory() {
    if (location.value == ExplorerLocation.directory &&
        currentPath.value.isNotEmpty) {
      pathHistory.add(currentPath.value);
    }
  }

  Future<void> navigateTo(String path) async {
    if (location.value == ExplorerLocation.directory &&
        path == currentPath.value) {
      return;
    }

    _pushCurrentToHistory();
    forwardHistory.clear();
    await loadDirectory(path);
  }

  Future<void> goBack() async {
    if (pathHistory.isEmpty) return;

    final String previous = pathHistory.removeLast();
    if (location.value == ExplorerLocation.directory) {
      forwardHistory.add(currentPath.value);
    }

    await loadDirectory(previous);
  }

  Future<void> goForward() async {
    if (forwardHistory.isEmpty) return;

    final String next = forwardHistory.removeLast();
    if (location.value == ExplorerLocation.directory) {
      pathHistory.add(currentPath.value);
    }

    await loadDirectory(next);
  }

  Future<void> goToParent() async {
    final String parentPath = p.dirname(currentPath.value);

    if (parentPath == currentPath.value) return;

    await navigateTo(parentPath);
  }

  Future<void> refreshDirectory() async {
    if (location.value == ExplorerLocation.recent) {
      await _loadRecentEntries();
      return;
    }

    await loadDirectory(currentPath.value);
  }

  void setViewMode(ExplorerViewMode mode) => viewMode.value = mode;

  void toggleSidebar() => showSidebar.toggle();

  void startSearch() => isSearching.value = true;

  void stopSearch() {
    isSearching.value = false;
    searchQuery.value = '';
  }

  void updateSearch(String value) => searchQuery.value = value;

  rust.FileEntry? get primarySelection =>
      selection.isEmpty ? null : selection.last;

  bool get hasClipboard => clipboardEntries.isNotEmpty;

  String get trashPath {
    for (final place in places) {
      if (place.kind == rust_system.PlaceKind.trash) {
        return place.path;
      }
    }

    return '';
  }

  String get trashRootPath {
    final String path = trashPath;
    if (path.isEmpty) return '';

    return p.basename(path) == 'files' ? p.dirname(path) : path;
  }

  bool isInTrash(String path) {
    final String root = trashRootPath;
    if (root.isEmpty) return false;

    return path == root || p.isWithin(root, path);
  }

  bool get isCurrentInTrash => isInTrash(currentPath.value);

  bool isSelected(rust.FileEntry entry) =>
      selection.any((selected) => selected.path == entry.path);

  void selectOnly(rust.FileEntry entry) {
    selection.assignAll([entry]);
    selectionAnchor.value = entry.path;
  }

  void toggleSelection(rust.FileEntry entry) {
    if (isSelected(entry)) {
      selection.assignAll(
        selection.where((selected) => selected.path != entry.path),
      );
    } else {
      selection.add(entry);
    }

    selectionAnchor.value = entry.path;
  }

  void selectRangeTo(rust.FileEntry entry) {
    final List<rust.FileEntry> list = visibleEntries;
    final String? anchorPath = selectionAnchor.value;
    final int targetIndex = list.indexWhere((item) => item.path == entry.path);
    final int anchorIndex = anchorPath == null
        ? -1
        : list.indexWhere((item) => item.path == anchorPath);

    if (targetIndex == -1 || anchorIndex == -1) {
      selectOnly(entry);
      return;
    }

    final int start = anchorIndex <= targetIndex ? anchorIndex : targetIndex;
    final int end = anchorIndex <= targetIndex ? targetIndex : anchorIndex;

    selection.assignAll(list.sublist(start, end + 1));
  }

  void selectAll() {
    final List<rust.FileEntry> list = visibleEntries;
    if (list.isEmpty) return;

    selection.assignAll(list);
    selectionAnchor.value = list.last.path;
  }

  void clearSelection() {
    selection.clear();
    selectionAnchor.value = null;
  }

  void _removeFromClipboard(String path) {
    if (!clipboardEntries.any((item) => item.path == path)) return;

    clipboardEntries.assignAll(
      clipboardEntries.where((item) => item.path != path),
    );
  }

  void copyToClipboard(List<rust.FileEntry> entries) {
    if (entries.isEmpty) return;

    clipboardEntries.assignAll(entries);
    clipboardIsCut.value = false;

    Get.snackbar(
      'Disalin',
      entries.length == 1
          ? '"${entries.first.name}" siap disalin ke folder lain.'
          : '${entries.length} item siap disalin ke folder lain.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void cutToClipboard(List<rust.FileEntry> entries) {
    if (entries.isEmpty) return;

    clipboardEntries.assignAll(entries);
    clipboardIsCut.value = true;

    Get.snackbar(
      'Dipindahkan',
      entries.length == 1
          ? '"${entries.first.name}" siap dipindahkan ke folder lain.'
          : '${entries.length} item siap dipindahkan ke folder lain.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> pasteIntoCurrentDirectory() async {
    final List<rust.FileEntry> items = List<rust.FileEntry>.of(
      clipboardEntries,
    );
    if (items.isEmpty) return;

    final bool cut = clipboardIsCut.value;
    if (cut) clipboardEntries.clear();

    await _transferEntries(
      entries: items,
      destinationDirectory: currentPath.value,
      move: cut,
    );
  }

  Future<void> _transferEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
    required bool move,
    String? newName,
  }) async {
    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        if (move) {
          await fileSystemService.moveEntry(
            sourcePath: entry.path,
            destinationDirectory: destinationDirectory,
            newName: newName ?? entry.name,
          );
        } else {
          await fileSystemService.copyEntry(
            sourcePath: entry.path,
            destinationDirectory: destinationDirectory,
            newName: newName ?? entry.name,
          );
        }

        succeeded++;
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    final String label = move ? 'dipindahkan' : 'disalin';

    if (succeeded == entries.length) {
      Get.snackbar('Berhasil', '${entries.length} item berhasil $label.');
    } else if (entries.length == 1 && lastError != null) {
      Get.snackbar('Gagal', lastError);
    } else {
      Get.snackbar(
        'Selesai sebagian',
        '$succeeded dari ${entries.length} item berhasil $label.',
      );
    }
  }

  Future<void> trashEntries(List<rust.FileEntry> entries) async {
    if (entries.isEmpty) return;

    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        await fileSystemService.moveToTrash(entry.path);
        succeeded++;
        _removeFromClipboard(entry.path);
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    if (succeeded == entries.length) {
      Get.snackbar(
        'Trash',
        '${entries.length} item dipindahkan ke Trash.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (entries.length == 1 && lastError != null) {
      Get.snackbar(
        'Gagal memindahkan ke Trash',
        lastError,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Sebagian gagal',
        '$succeeded dari ${entries.length} item dipindahkan ke Trash.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> trashEntry(rust.FileEntry entry) => trashEntries([entry]);

  Future<void> deletePermanently(List<rust.FileEntry> entries) async {
    if (entries.isEmpty) return;

    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        if (isInTrash(entry.path)) {
          await fileSystemService.deleteFromTrash(entry.path);
        } else {
          await fileSystemService.deleteEntryRecursive(entry.path);
        }

        succeeded++;
        _removeFromClipboard(entry.path);
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    if (succeeded == entries.length) {
      Get.snackbar(
        'Dihapus',
        '${entries.length} item dihapus permanen.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (entries.length == 1 && lastError != null) {
      Get.snackbar(
        'Gagal menghapus',
        lastError,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Sebagian gagal',
        '$succeeded dari ${entries.length} item berhasil dihapus.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> emptyTrash() async {
    try {
      final int removed = await fileSystemService.emptyTrash();
      await refreshDirectory();

      Get.snackbar(
        'Trash dikosongkan',
        '$removed item dihapus permanen.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Gagal mengosongkan Trash',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openTerminalAt(String path) async {
    try {
      await rust_system.openInTerminal(path: path);
    } catch (error) {
      Get.snackbar(
        'Terminal',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openTerminal() => openTerminalAt(currentPath.value);

  Future<void> copyEntry({
    required rust.FileEntry entry,
    required String destinationDirectory,
    String? newName,
  }) {
    return _transferEntries(
      entries: [entry],
      destinationDirectory: destinationDirectory,
      move: false,
      newName: newName,
    );
  }

  Future<void> copyEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
  }) {
    return _transferEntries(
      entries: entries,
      destinationDirectory: destinationDirectory,
      move: false,
    );
  }

  Future<void> moveEntry({
    required rust.FileEntry entry,
    required String destinationDirectory,
    String? newName,
  }) {
    return _transferEntries(
      entries: [entry],
      destinationDirectory: destinationDirectory,
      move: true,
      newName: newName,
    );
  }

  Future<void> moveEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
  }) {
    return _transferEntries(
      entries: entries,
      destinationDirectory: destinationDirectory,
      move: true,
    );
  }

  Future<void> renameEntry(rust.FileEntry entry, String newName) async {
    final String trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      Get.snackbar(
        'Nama kosong',
        'Masukkan nama baru terlebih dahulu.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await fileSystemService.renameEntry(entry.path, trimmedName);
      await refreshDirectory();

      Get.snackbar(
        'Berhasil',
        '"${entry.name}" berhasil diganti namanya.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Gagal rename',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> createDirectory(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      Get.snackbar(
        'Nama folder kosong',
        'Masukkan nama folder terlebih dahulu',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await fileSystemService.createDirectory(currentPath.value, trimmedName);
      await refreshDirectory();

      Get.snackbar(
        'Berhasil',
        'Folder "$trimmedName" berhasil dibuat',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'Gagal membuat folder',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openDirectory(rust.FileEntry entry) async {
    if (!entry.isDirectory) return;
    await navigateTo(entry.path);
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
