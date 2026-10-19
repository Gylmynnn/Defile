import 'package:defile/src/features/file_explorer/services/file_system_service.dart';

import '../utils/app_toast.dart';

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
  final RxList<rust_system.Place> quickPlaces = <rust_system.Place>[].obs;
  final RxList<rust_system.Place> folderPlaces = <rust_system.Place>[].obs;
  final RxList<rust_system.Place> drivePlaces = <rust_system.Place>[].obs;
  final RxMap<String, rust_system.DiskUsage> driveUsages =
      <String, rust_system.DiskUsage>{}.obs;
  final Rxn<rust_system.DiskUsage> diskUsage = Rxn();

  int _entriesRevision = 0;
  List<rust.FileEntry>? _visibleCache;
  int _visibleCacheRevision = -1;
  String? _visibleCacheQuery;

  List<String>? _breadcrumbsCache;
  String? _breadcrumbsKey;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final Rx<ExplorerLocation> location = ExplorerLocation.directory.obs;

  final Rx<ExplorerViewMode> viewMode = ExplorerViewMode.grid.obs;
  final RxBool showSidebar = true.obs;
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  final RxList<rust.FileEntry> selection = <rust.FileEntry>[].obs;
  final RxSet<String> selectedPaths = <String>{}.obs;
  final RxnString selectionAnchor = RxnString();
  final RxList<rust.FileEntry> clipboardEntries = <rust.FileEntry>[].obs;
  final RxBool clipboardIsCut = false.obs;

  final Rxn<rust.FileEntry> previewFile = Rxn();

  final RxList<String> pathHistory = <String>[].obs;
  final RxList<String> forwardHistory = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    ever(entries, (_) => _entriesRevision++);
    ever(
      selection,
      (_) => selectedPaths.assignAll(selection.map((e) => e.path)),
    );
    ever(places, (_) {
      quickPlaces.assignAll(
        places.where(
          (place) =>
              place.kind != rust_system.PlaceKind.folder &&
              place.kind != rust_system.PlaceKind.drive,
        ),
      );
      folderPlaces.assignAll(
        places.where((place) => place.kind == rust_system.PlaceKind.folder),
      );
      drivePlaces.assignAll(
        places.where((place) => place.kind == rust_system.PlaceKind.drive),
      );
    });
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

    if (_visibleCache != null &&
        _visibleCacheRevision == _entriesRevision &&
        _visibleCacheQuery == query &&
        _visibleCache!.length == entries.length) {
      return _visibleCache!;
    }

    final List<rust.FileEntry> result = query.isEmpty
        ? entries
        : entries
              .where((entry) => entry.name.toLowerCase().contains(query))
              .toList();

    _visibleCache = result;
    _visibleCacheRevision = _entriesRevision;
    _visibleCacheQuery = query;
    return result;
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

    if (_breadcrumbsCache != null && _breadcrumbsKey == normalized) {
      return _breadcrumbsCache!;
    }

    final List<String> parts = p.split(normalized);

    final List<String> result = <String>[];
    String accumulatedPath = p.rootPrefix(normalized);

    for (final String part in parts) {
      if (part == p.rootPrefix(normalized)) continue;

      accumulatedPath = p.join(accumulatedPath, part);
      result.add(accumulatedPath);
    }

    _breadcrumbsKey = normalized;
    _breadcrumbsCache = result;
    return result;
  }

  Future<void> loadDirectory(String path) async {
    isLoading.value = true;
    errorMessage.value = null;
    location.value = ExplorerLocation.directory;
    clearSelection();
    previewFile.value = null;

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
        showAppToast(
          title: 'Network',
          message: 'Network browsing is not supported yet.',
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
      showAppToast(
        title: 'Trash',
        message: 'Trash is not available on this platform.',
      );
      return;
    }

    try {
      await fileSystemService.listDirectory(trashPath);
    } catch (_) {
      showAppToast(title: 'Trash', message: 'Trash folder is empty.');
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

  bool isSelected(rust.FileEntry entry) => selectedPaths.contains(entry.path);

  void selectOnly(rust.FileEntry entry) {
    selection.assignAll([entry]);
    selectionAnchor.value = entry.path;
    previewFile.value = entry;
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

    showAppToast(
      title: 'Copied',
      message: entries.length == 1
          ? '"${entries.first.name}" is ready to be copied to another folder.'
          : '${entries.length} items ready to be copied to another folder.',
    );
  }

  void cutToClipboard(List<rust.FileEntry> entries) {
    if (entries.isEmpty) return;

    clipboardEntries.assignAll(entries);
    clipboardIsCut.value = true;

    showAppToast(
      title: 'Cut',
      message: entries.length == 1
          ? '"${entries.first.name}" is ready to be moved to another folder.'
          : '${entries.length} items ready to be moved to another folder.',
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

    final String label = move ? 'moved' : 'copied';

    if (succeeded == entries.length) {
      showAppToast(
        title: 'Success',
        message: '${entries.length} item(s) $label.',
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(title: 'Failed', message: lastError);
    } else {
      showAppToast(
        title: 'Partially completed',
        message: '$succeeded of ${entries.length} items $label.',
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
      showAppToast(
        title: 'Trash',
        message: '${entries.length} item(s) moved to Trash.',
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(title: 'Failed to move to Trash', message: lastError);
    } else {
      showAppToast(
        title: 'Partially failed',
        message: '$succeeded of ${entries.length} items moved to Trash.',
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
      showAppToast(
        title: 'Deleted',
        message: '${entries.length} item(s) permanently deleted.',
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(title: 'Failed to delete', message: lastError);
    } else {
      showAppToast(
        title: 'Partially failed',
        message: '$succeeded of ${entries.length} items deleted.',
      );
    }
  }

  Future<void> emptyTrash() async {
    try {
      final int removed = await fileSystemService.emptyTrash();
      await refreshDirectory();

      showAppToast(
        title: 'Trash emptied',
        message: '$removed item(s) permanently deleted.',
      );
    } catch (error) {
      showAppToast(title: 'Failed to empty Trash', message: error.toString());
    }
  }

  Future<void> openTerminalAt(String path) async {
    try {
      await rust_system.openInTerminal(path: path);
    } catch (error) {
      showAppToast(title: 'Terminal', message: error.toString());
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
      showAppToast(title: 'Empty name', message: 'Enter a new name first.');
      return;
    }

    try {
      await fileSystemService.renameEntry(entry.path, trimmedName);
      await refreshDirectory();

      showAppToast(title: 'Success', message: '"${entry.name}" was renamed.');
    } catch (error) {
      showAppToast(title: 'Rename failed', message: error.toString());
    }
  }

  Future<void> createDirectory(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      showAppToast(
        title: 'Empty folder name',
        message: 'Enter a folder name first',
      );
      return;
    }

    try {
      await fileSystemService.createDirectory(currentPath.value, trimmedName);
      await refreshDirectory();

      showAppToast(title: 'Success', message: 'Folder "$trimmedName" created');
    } catch (error) {
      showAppToast(title: 'Failed to create folder', message: error.toString());
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
      showAppToast(title: 'Failed to open file', message: error.toString());
    }
  }

  Future<List<rust_system.OpenWithApp>> listOpenWithApps(String path) {
    return fileSystemService.listOpenWithApps(path);
  }

  Future<void> openWith(
    rust.FileEntry entry,
    rust_system.OpenWithApp app,
  ) async {
    try {
      await fileSystemService.openWith(entry.path, app.id);
    } catch (error) {
      showAppToast(title: 'Failed to open file', message: error.toString());
    }
  }
}
