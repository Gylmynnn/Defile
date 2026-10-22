part of 'file_explorer_controller.dart';

extension ExplorerSelection on FileExplorerController {
  void setViewMode(ExplorerViewMode mode) => viewMode.value = mode;

  void toggleSidebar() => showSidebar.toggle();

  void startSearch() => isSearching.value = true;

  void stopSearch() {
    isSearching.value = false;
    searchQuery.value = '';
    searchFocusNode.unfocus();
    keyboardFocusNode.requestFocus();
  }

  void updateSearch(String value) => searchQuery.value = value;

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
