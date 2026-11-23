part of 'file_explorer_controller.dart';

/// One directory listing held by the Miller-columns cache: the raw entries as
/// the filesystem returned them plus the last derived (filtered + sorted) list,
/// tagged with the filter signature that produced it.
class _ColumnListing {
  _ColumnListing(this.raw);

  final List<rust.FileEntry> raw;
  List<rust.FileEntry>? derived;
  ExplorerSortField? field;
  bool? ascending;
  bool? hidden;
}

/// Miller-columns ("nested list" / yazi) support.
///
/// The layout shows three panes: the parent folder, the active folder and a
/// preview of the focused folder. Only the active folder lives in [entries];
/// the two side panes are loaded here on demand and guarded by generation
/// counters so fast navigation cannot paint a stale listing.
///
/// Keeping this cheap is the whole point of the layout:
///  * listings are cached per path (small LRU), so flipping between siblings or
///    re-previewing a folder never touches the disk twice;
///  * the displayed parent folder is left untouched when navigation keeps the
///    same parent (sibling switches), so not even a rebuild happens;
///  * sort / dot-file toggles only re-derive from cache;
///  * cursor moves are debounced into a single filesystem read.
extension ExplorerColumns on FileExplorerController {
  bool get isColumnsLayout =>
      viewMode.value == ExplorerViewMode.columns &&
      location.value == ExplorerLocation.directory;

  /// Loads both side panes. Safe to call from anywhere: it no-ops unless the
  /// Miller-columns layout is active. [reload] re-reads the filesystem
  /// (explicit refresh); with `false` cached listings are reused.
  Future<void> refreshColumns({bool reload = true}) async {
    if (!isColumnsLayout) return;

    await Future.wait([
      _loadParentColumn(reload: reload),
      _loadPreviewColumn(reload: reload),
    ]);
  }

  /// Drops the side-pane listings when another layout takes over.
  void clearColumns() {
    _columnPreviewDebounce?.cancel();
    _columnParentGeneration++;
    _columnPreviewGeneration++;
    _columnListings.clear();
    _columnParentShownPath = '';
    _columnPreviewShownPath = '';
    columnParentEntries.clear();
    columnPreviewEntries.clear();
    columnPreviewPath.value = '';
    columnPreviewFile.value = null;
  }

  /// Remembers a freshly read directory listing so the side panes (and a later
  /// re-entry) resolve it without another filesystem read. Called by
  /// [loadDirectory] for the active folder, which is exactly the parent column
  /// that the next descent needs.
  void seedColumnListing(String path, List<rust.FileEntry> raw) {
    if (path.isEmpty) return;

    _columnListings.remove(path);
    _columnListings[path] = _ColumnListing(raw);
    _trimColumnListings();
  }

  void _trimColumnListings() {
    while (_columnListings.length >
        FileExplorerController._columnListingCacheMax) {
      _columnListings.remove(_columnListings.keys.first);
    }
  }

  /// Debounced preview refresh for cursor moves. Multiple selection changes
  /// within the debounce window collapse into a single refresh, and a move
  /// that returns to the already-previewed folder does nothing at all.
  void scheduleColumnPreview() {
    if (viewMode.value != ExplorerViewMode.columns) return;

    _columnPreviewDebounce?.cancel();
    _columnPreviewDebounce = Timer(
      FileExplorerController._columnPreviewDebounceDelay,
      () {
        if (columnPreviewTarget == columnPreviewPath.value) return;
        unawaited(_loadPreviewColumn(reload: false));
      },
    );
  }

  Future<void> _loadParentColumn({required bool reload}) async {
    final String path = currentPath.value;
    final String parent = path.isEmpty ? '' : p.dirname(path);

    if (parent.isEmpty || parent == path) {
      _columnParentShownPath = '';
      columnParentEntries.clear();
      return;
    }

    // Navigation that keeps the same parent (a sibling switch) leaves the
    // parent pane exactly as it is — no read, no rebuild — unless the filters
    // changed under it.
    if (!reload && _columnParentShownPath == parent) {
      final _ColumnListing? listing = _columnListings[parent];
      if (listing == null || _matchesFilters(listing)) return;
      columnParentEntries.assignAll(_derive(listing));
      return;
    }

    final int generation = ++_columnParentGeneration;
    final List<rust.FileEntry>? raw = await _fetchListing(parent, reload);
    if (generation != _columnParentGeneration) return;

    if (raw == null) {
      _columnParentShownPath = '';
      columnParentEntries.clear();
      return;
    }

    _columnParentShownPath = parent;
    columnParentEntries.assignAll(_derive(_columnListings[parent]!));
  }

  /// Path of the entry whose preview should fill the preview column. Files have
  /// no folder listing but still preview (their content), so any single
  /// selection resolves here.
  String get columnPreviewTarget {
    final List<rust.FileEntry> selected = selection;
    if (selected.length != 1) return '';

    return selected.single.path;
  }

  Future<void> _loadPreviewColumn({required bool reload}) async {
    final List<rust.FileEntry> selected = selection;
    final rust.FileEntry? entry = selected.length == 1 ? selected.single : null;

    if (entry == null) {
      _columnPreviewShownPath = '';
      columnPreviewPath.value = '';
      columnPreviewFile.value = null;
      columnPreviewEntries.clear();
      return;
    }

    // A file previews its content in the pane instead of listing a folder, so
    // a click that lands on an image or document shows it before opening.
    if (!entry.isDirectory) {
      _columnPreviewShownPath = '';
      columnPreviewEntries.clear();
      _columnPreviewGeneration++;
      columnPreviewFile.value = entry;
      columnPreviewPath.value = entry.path;
      return;
    }

    final String path = entry.path;
    columnPreviewFile.value = null;
    columnPreviewPath.value = path;

    // Already showing this folder: re-selects and back-and-forth cursor moves
    // resolve from the cache without a filesystem read.
    if (!reload && _columnPreviewShownPath == path) {
      final _ColumnListing? listing = _columnListings[path];
      if (listing == null || _matchesFilters(listing)) return;
      columnPreviewEntries.assignAll(_derive(listing));
      return;
    }

    final int generation = ++_columnPreviewGeneration;
    final List<rust.FileEntry>? raw = await _fetchListing(path, reload);
    if (generation != _columnPreviewGeneration) return;

    if (raw == null) {
      _columnPreviewShownPath = '';
      columnPreviewPath.value = '';
      columnPreviewEntries.clear();
      return;
    }

    _columnPreviewShownPath = path;
    columnPreviewEntries.assignAll(_derive(_columnListings[path]!));
  }

  /// Returns a directory's raw listing, from the cache unless [reload] forces
  /// a fresh read. Stores successful reads in the LRU. Null on failure.
  Future<List<rust.FileEntry>?> _fetchListing(String path, bool reload) async {
    final _ColumnListing? cached = _columnListings[path];
    if (cached != null && !reload) return cached.raw;

    try {
      final List<rust.FileEntry> raw = await fileSystemService.listDirectory(
        path,
      );
      _columnListings.remove(path);
      _columnListings[path] = _ColumnListing(raw);
      _trimColumnListings();
      return raw;
    } catch (_) {
      return null;
    }
  }

  bool _matchesFilters(_ColumnListing listing) =>
      listing.derived != null &&
      listing.field == sortField.value &&
      listing.ascending == sortAscending.value &&
      listing.hidden == showHidden.value;

  /// Applies the dot-file preference and the active sort order to a cached
  /// listing, remembering the result until the filters change. The search
  /// query only filters the active column.
  List<rust.FileEntry> _derive(_ColumnListing listing) {
    if (_matchesFilters(listing)) return listing.derived!;

    List<rust.FileEntry> result = listing.raw;
    if (!showHidden.value) {
      result = result.where((entry) => !entry.name.startsWith('.')).toList();
    }

    listing.derived = FileExplorerController._sortedEntries(
      result,
      sortField.value,
      sortAscending.value,
    );
    listing.field = sortField.value;
    listing.ascending = sortAscending.value;
    listing.hidden = showHidden.value;
    return listing.derived!;
  }
}
