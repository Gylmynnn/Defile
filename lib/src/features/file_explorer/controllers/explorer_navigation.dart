part of 'file_explorer_controller.dart';

extension ExplorerNavigation on FileExplorerController {
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
        variant: AppToastVariant.error,
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
}
