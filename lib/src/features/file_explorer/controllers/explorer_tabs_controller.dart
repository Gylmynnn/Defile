import 'package:get/get.dart';

import '../services/file_system_service.dart';
import 'file_explorer_controller.dart';

/// State of a closed tab preserved for reopening (Ctrl+Shift+T).
class ClosedTabState {
  const ClosedTabState({
    required this.path,
    required this.location,
    required this.viewMode,
  });

  final String path;
  final ExplorerLocation location;
  final ExplorerViewMode viewMode;
}

/// A single browser-like tab. Each tab owns an independent
/// [FileExplorerController] so directory, history, selection and view mode are
/// preserved while switching.
class ExplorerTab {
  ExplorerTab({required this.id, required this.controller});

  final int id;
  final FileExplorerController controller;
}

/// Owns the collection of open tabs and the active one.
///
/// The controllers are created manually instead of being registered in GetX:
/// their lifecycle (`onStart` / `onDelete`) is driven here so every tab keeps
/// its own state without colliding on a single singleton key.
class ExplorerTabsController extends GetxService {
  ExplorerTabsController(this._fileSystemService);

  final FileSystemService _fileSystemService;

  final RxList<ExplorerTab> tabs = <ExplorerTab>[].obs;
  final RxInt activeIndex = 0.obs;

  final List<ClosedTabState> _recentlyClosed = <ClosedTabState>[];

  int _nextId = 0;

  ExplorerTab get activeTab => tabs[activeIndex.value];

  FileExplorerController get activeController => activeTab.controller;

  bool get canCloseTabs => tabs.length > 1;

  bool get canReopenClosedTab => _recentlyClosed.isNotEmpty;

  @override
  void onInit() {
    super.onInit();

    if (tabs.isEmpty) {
      addTab();
    }
  }

  @override
  void onClose() {
    for (final tab in tabs) {
      tab.controller.onDelete();
    }
    tabs.clear();
    _recentlyClosed.clear();
    super.onClose();
  }

  /// Opens a new tab and makes it active. When [path] is given the tab starts
  /// in that directory instead of Home. When [location] is given it starts
  /// in that location (e.g. recent or trash).
  ExplorerTab addTab({String? path, ExplorerLocation? location}) {
    final tab = ExplorerTab(
      id: _nextId++,
      controller: FileExplorerController(
        _fileSystemService,
        initialPath: path,
        initialLocation: location,
      ),
    );

    // Reuse the system state (places, drive usage, terminal) of the tab this
    // one was opened from instead of repeating the expensive discovery.
    if (tabs.isNotEmpty) {
      tab.controller.seedSystemState(tabs[activeIndex.value].controller);
    }

    tab.controller.onStart();

    tabs.add(tab);
    activeIndex.value = tabs.length - 1;
    return tab;
  }

  /// Duplicates the tab at [index], preserving its directory/location and view mode.
  ExplorerTab duplicateTab(int index) {
    if (index < 0 || index >= tabs.length) return addTab();

    final FileExplorerController source = tabs[index].controller;
    final ExplorerTab newTab = addTab(
      path: source.location.value == ExplorerLocation.directory
          ? source.currentPath.value
          : null,
      location: source.location.value,
    );

    newTab.controller.viewMode.value = source.viewMode.value;
    return newTab;
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;
    if (activeIndex.value == index) return;

    activeIndex.value = index;
  }

  /// Cycles between tabs. [delta] of `1` goes forward, `-1` backward, wrapping
  /// around at both ends.
  void selectRelative(int delta) {
    if (tabs.length < 2) return;

    final int count = tabs.length;
    final int next = (activeIndex.value + delta) % count;
    activeIndex.value = next < 0 ? next + count : next;
  }

  void closeTab(int index) {
    if (index < 0 || index >= tabs.length) return;
    if (tabs.length == 1) return;

    final ExplorerTab tab = tabs.removeAt(index);

    _recentlyClosed.add(
      ClosedTabState(
        path: tab.controller.currentPath.value,
        location: tab.controller.location.value,
        viewMode: tab.controller.viewMode.value,
      ),
    );
    if (_recentlyClosed.length > 10) {
      _recentlyClosed.removeAt(0);
    }

    tab.controller.onDelete();

    if (activeIndex.value > index) {
      activeIndex.value -= 1;
    } else if (activeIndex.value == index) {
      activeIndex.value = index.clamp(0, tabs.length - 1);
    }
  }

  void closeActiveTab() => closeTab(activeIndex.value);

  void closeOtherTabs(int index) {
    if (index < 0 || index >= tabs.length) return;

    for (int i = tabs.length - 1; i >= 0; i--) {
      if (i == index) continue;

      final ExplorerTab tab = tabs.removeAt(i);
      tab.controller.onDelete();
    }

    activeIndex.value = 0;
  }

  void closeTabsToTheRight(int index) {
    if (index < 0 || index >= tabs.length - 1) return;

    for (int i = tabs.length - 1; i > index; i--) {
      final ExplorerTab tab = tabs.removeAt(i);
      tab.controller.onDelete();
    }

    if (activeIndex.value > index) {
      activeIndex.value = index;
    }
  }

  /// Reopens the last closed tab (Ctrl+Shift+T).
  ExplorerTab? reopenClosedTab() {
    if (_recentlyClosed.isEmpty) return null;

    final ClosedTabState state = _recentlyClosed.removeLast();
    final ExplorerTab tab = addTab(
      path: state.location == ExplorerLocation.directory ? state.path : null,
      location: state.location,
    );
    tab.controller.viewMode.value = state.viewMode;
    return tab;
  }

  /// Reorders a tab from [oldIndex] to [newIndex].
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= tabs.length) return;
    if (newIndex < 0 || newIndex > tabs.length) return;

    final int activeId = activeTab.id;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final ExplorerTab tab = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);

    activeIndex.value = tabs.indexWhere((t) => t.id == activeId);
  }
}
