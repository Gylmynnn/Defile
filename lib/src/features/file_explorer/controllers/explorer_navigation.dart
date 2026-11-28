part of 'file_explorer_controller.dart';

extension ExplorerNavigation on FileExplorerController {
  Future<void> _loadPlaces() async {
    final int generation = ++_placesGeneration;

    List<rust_system.Place> base = const <rust_system.Place>[];
    try {
      base = await rust_system.listPlaces();
    } catch (_) {
      base = const <rust_system.Place>[];
    }

    // A slower list that finished after a newer one must not clobber it.
    if (generation != _placesGeneration) return;

    final List<rust_system.Place> merged = _mergePlaces(base);
    places.assignAll(merged);
    // `ever(places, ...)` already splits the sections, but doing it here keeps
    // the drive list available below even if the worker ran late.
    _splitPlaces();

    await Future.wait([
      for (final drive in merged)
        if (drive.kind == rust_system.PlaceKind.drive &&
            !drive.path.contains('/gvfs/'))
          () async {
            try {
              driveUsages[drive.path] = await rust_system.getDiskUsage(
                path: drive.path,
              );
            } catch (_) {}
          }(),
    ]);
  }

  /// Combines the Rust-provided places with the [DriveService] listing.
  ///
  /// Rust only knows a single hard-coded drive ("/"), so its drive entries are
  /// dropped and replaced by the discovered mounts (root plus removable media).
  /// Without a [DriveService] (non-Linux, or before binding) the list is left
  /// untouched.
  List<rust_system.Place> _mergePlaces(List<rust_system.Place> base) {
    final DriveService? service = _driveService;
    if (service == null) return base;

    final List<rust_system.Place> merged = <rust_system.Place>[
      for (final place in base)
        if (place.kind != rust_system.PlaceKind.drive) place,
    ];
    merged.addAll(service.drives);

    return merged;
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

  bool get canGoToParent {
    if (location.value != ExplorerLocation.directory) return false;

    final String path = currentPath.value;
    final String? mountRoot = _gvfsMountRootPath(path);
    // The phone's gvfs mount is a root of its own; going above it would expose
    // the runtime-directory plumbing.
    if (mountRoot != null && mountRoot == path) return false;

    return p.dirname(path) != path;
  }

  String crumbLabel(String path) {
    if (path == homePath.value) return 'Home';

    if (p.basename(path).startsWith('mtp:')) {
      // gvfs mount roots carry an encoded spec; show the friendly drive label.
      for (final place in drivePlaces) {
        if (place.path == path) return place.label;
      }
      return 'Phone';
    }

    final String base = p.basename(path);
    return base.isEmpty ? path : base;
  }

  /// Root of the gvfs MTP mount that [path] lives under, e.g.
  /// `/run/user/1000/gvfs/mtp:host=Pixel_5`, or null for normal paths.
  /// Breadcrumbs start here so the phone reads as one root instead of exposing
  /// the runtime-directory chain.
  String? _gvfsMountRootPath(String path) {
    final List<String> parts = p.split(path);
    for (int index = 0; index < parts.length - 1; index++) {
      if (parts[index] == 'gvfs' && parts[index + 1].startsWith('mtp:')) {
        return p.joinAll(parts.sublist(0, index + 2));
      }
    }
    return null;
  }

  List<String> get breadcrumbs {
    final String normalized = p.normalize(currentPath.value);

    if (_breadcrumbsCache != null && _breadcrumbsKey == normalized) {
      return _breadcrumbsCache!;
    }

    final String? mountRoot = _gvfsMountRootPath(normalized);
    final String anchor = mountRoot ?? p.rootPrefix(normalized);
    final String relative = mountRoot == null
        ? normalized
        : normalized.substring(mountRoot.length);

    final List<String> result = <String>[];
    String accumulatedPath = anchor;
    if (mountRoot != null) result.add(mountRoot);

    for (final String part in p.split(relative)) {
      if (part == p.rootPrefix(relative) || part.isEmpty) continue;

      accumulatedPath = p.join(accumulatedPath, part);
      result.add(accumulatedPath);
    }

    _breadcrumbsKey = normalized;
    _breadcrumbsCache = result;
    return result;
  }

  /// Loads [path] into the active pane. [force] marks an explicit refresh
  /// (F5, post-operation): only then are the decoded-image cache and the
  /// side-pane listings dropped, so ordinary browsing keeps thumbnails warm
  /// and the Miller-columns cache reusable.
  Future<void> loadDirectory(String path, {bool force = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    location.value = ExplorerLocation.directory;
    clearSelection();
    previewFile.value = null;
    if (force) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    try {
      // In the Miller-columns layout a freshly listed folder is remembered for
      // the side panes; when the same folder is opened again (walking back down
      // a deep tree, or up into the parent) it is served from that cache
      // instead of re-reading the disk. Explicit refreshes bypass it.
      final _ColumnListing? cached = (!force && isColumnsLayout)
          ? _columnListings[path]
          : null;

      final List<rust.FileEntry> result =
          cached?.raw ?? await fileSystemService.listDirectory(path);

      entries.assignAll(result);
      currentPath.value = path;
      if (viewMode.value == ExplorerViewMode.columns) {
        seedColumnListing(path, result);
      }
      _refreshDiskUsage(path);
      unawaited(refreshColumns(reload: force));
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
    previewFile.value = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

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
    final String path = currentPath.value;
    final String? mountRoot = _gvfsMountRootPath(path);
    if (mountRoot != null && mountRoot == path) return;

    final String parentPath = p.dirname(path);

    if (parentPath == path) return;

    await navigateTo(parentPath);
  }

  /// Enters type-a-path mode for the location bar (`Ctrl+L`).
  void startPathEdit() {
    if (location.value != ExplorerLocation.directory) return;

    isEditingPath.value = true;
  }

  /// Leaves type-a-path mode without navigating.
  void cancelPathEdit() {
    if (!isEditingPath.value) return;

    isEditingPath.value = false;
    keyboardFocusNode.requestFocus();
  }

  /// Navigates to the path typed in the location bar. `~` expands to Home and
  /// a relative path resolves against the current folder.
  Future<void> submitPathEdit(String raw) async {
    final String target = _resolveInputPath(raw);
    isEditingPath.value = false;

    if (target.isEmpty) {
      keyboardFocusNode.requestFocus();
      return;
    }

    await navigateTo(target);
  }

  String _resolveInputPath(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return '';

    if (value == '~') {
      value = homePath.value;
    } else if (value.startsWith('~/')) {
      value = p.join(homePath.value, value.substring(2));
    }

    if (!p.isAbsolute(value)) {
      value = p.join(currentPath.value, value);
    }

    return p.normalize(value);
  }

  Future<void> refreshDirectory() async {
    if (location.value == ExplorerLocation.recent) {
      await _loadRecentEntries();
      return;
    }

    await loadDirectory(currentPath.value, force: true);
  }
}
