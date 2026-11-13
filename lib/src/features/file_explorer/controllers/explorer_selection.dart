part of 'file_explorer_controller.dart';

extension ExplorerSelection on FileExplorerController {
  void setViewMode(ExplorerViewMode mode) => viewMode.value = mode;

  void toggleSidebar() => showSidebar.toggle();

  /// Applies a new sort key and remembers it for the next launch.
  void setSortField(ExplorerSortField field) {
    if (sortField.value == field) return;

    sortField.value = field;
    unawaited(_persistViewSetting('sort-field', field.name));
  }

  /// Flips ascending/descending for the active sort key.
  void toggleSortDirection() {
    sortAscending.value = !sortAscending.value;
    unawaited(_persistViewSetting('sort-ascending', '${sortAscending.value}'));
  }

  void setSortAscending(bool value) {
    if (sortAscending.value == value) return;

    sortAscending.value = value;
    unawaited(_persistViewSetting('sort-ascending', '$value'));
  }

  /// Shows or hides dot-files (also bound to `Ctrl+H`).
  void toggleHiddenFiles() {
    showHidden.value = !showHidden.value;
    unawaited(_persistViewSetting('show-hidden', '${showHidden.value}'));
  }

  Future<void> _persistViewSetting(String key, String value) async {
    try {
      await rust_system.setViewSetting(key: key, value: value);
    } catch (_) {}
  }

  /// Restores sort/hidden preferences from disk. Called once per tab that owns
  /// its own system state; sibling tabs inherit the values via
  /// [seedSystemState].
  Future<void> _loadViewSettings() async {
    try {
      final String field = await rust_system.getViewSetting(key: 'sort-field');
      for (final ExplorerSortField candidate in ExplorerSortField.values) {
        if (candidate.name == field) {
          sortField.value = candidate;
          break;
        }
      }
    } catch (_) {}

    try {
      final String ascending = await rust_system.getViewSetting(
        key: 'sort-ascending',
      );
      if (ascending.isNotEmpty) sortAscending.value = ascending == 'true';
    } catch (_) {}

    try {
      final String hidden = await rust_system.getViewSetting(
        key: 'show-hidden',
      );
      if (hidden.isNotEmpty) showHidden.value = hidden == 'true';
    } catch (_) {}
  }

  void startSearch() => isSearching.value = true;

  void stopSearch() {
    isSearching.value = false;
    searchQuery.value = '';
    resetPathSearch();
    searchFocusNode.unfocus();
    keyboardFocusNode.requestFocus();
  }

  /// Key handler attached to [FileExplorerController.searchFocusNode]: `Esc`
  /// leaves search mode (unfocus, clear, return keyboard focus to the file
  /// list); `/` stays a normal character so path queries like
  /// `.config/nvim` can be typed.
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      stopSearch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void updateSearch(String value) {
    searchQuery.value = value;
    schedulePathSearch();
  }

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
}
