import 'package:get/get.dart';

import '../services/file_system_service.dart';
import 'file_explorer_controller.dart';

/// Layout mode of the content area: single pane or two panes side by side
/// (horizontal) / stacked (vertical).
enum ExplorerSplitMode { none, horizontal, vertical }

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

  /// Whether the content area is split and the id of the tab filling the
  /// second pane. The active tab always occupies the first pane.
  final Rx<ExplorerSplitMode> splitMode = ExplorerSplitMode.none.obs;
  final RxnInt splitPartnerId = RxnInt();

  /// Whether pane two (the partner pane) currently holds keyboard focus;
  /// drives which pane owns the toolbar-wide preview panel.
  final RxBool splitFocusSecond = false.obs;

  /// Ratio of the split (between 0.15 and 0.85). 0.5 means equal width/height.
  final RxDouble splitRatio = 0.5.obs;

  final List<ClosedTabState> _recentlyClosed = <ClosedTabState>[];

  int _nextId = 0;

  ExplorerTab get activeTab => tabs[activeIndex.value];

  FileExplorerController get activeController => activeTab.controller;

  bool get isSplit => splitMode.value != ExplorerSplitMode.none;

  /// The tab filling the second pane, or `null` when the split was cleared or
  /// its partner tab has been closed.
  ExplorerTab? get partnerTab {
    final int? id = splitPartnerId.value;
    if (id == null) return null;

    for (final ExplorerTab tab in tabs) {
      if (tab.id == id) return tab;
    }

    return null;
  }

  /// Controller whose state the shared UI (sidebar, preview panel) reflects.
  FileExplorerController get focusedController {
    if (!isSplit) return activeController;

    final ExplorerTab? partner = partnerTab;
    if (partner == null) return activeController;

    return splitFocusSecond.value ? partner.controller : activeController;
  }

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
  /// in that location (e.g. recent or trash). Set [activate] to `false` to
  /// keep the current tab active (used when a split partner opens).
  ExplorerTab addTab({
    String? path,
    ExplorerLocation? location,
    bool activate = true,
  }) {
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
    if (activate) {
      if (isSplit && splitFocusSecond.value) {
        splitPartnerId.value = tab.id;
      } else {
        activeIndex.value = tabs.length - 1;
      }
    }
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

  /// Updates the split divider ratio, clamped to `[0.15, 0.85]`.
  void updateSplitRatio(double deltaRatio) {
    splitRatio.value = (splitRatio.value + deltaRatio).clamp(0.15, 0.85);
  }

  /// Resets the split divider ratio back to an even `0.5`.
  void resetSplitRatio() {
    splitRatio.value = 0.5;
  }

  /// Applies [mode] directly. When enabling the split with no partner live
  /// yet, a partner tab duplicating the active one is created first.
  void setSplitMode(ExplorerSplitMode mode) {
    if (mode == splitMode.value) return;
    if (mode == ExplorerSplitMode.none) return exitSplit();

    if (partnerTab == null) {
      splitPartnerId.value = _createPartnerTab().id;
      splitRatio.value = 0.5;
    }
    splitFocusSecond.value = false;
    splitMode.value = mode;
  }

  /// Duplicates the active tab (path, location and view mode) without
  /// activating it, for use as a split partner.
  ExplorerTab _createPartnerTab() {
    final FileExplorerController source = activeController;

    final ExplorerTab partner = addTab(
      path: source.location.value == ExplorerLocation.directory
          ? source.currentPath.value
          : null,
      location: source.location.value,
      activate: false,
    );
    partner.controller.viewMode.value = source.viewMode.value;
    return partner;
  }

  /// Cycles the split layout: off → side by side → stacked → off.
  ///
  /// Enabling the split opens a partner tab that duplicates the active
  /// directory/view mode and fills the second pane while the active tab keeps
  /// filling the first one; the partner stays open when the split is turned off.
  void cycleSplitMode() {
    switch (splitMode.value) {
      case ExplorerSplitMode.none:
        final ExplorerTab partner = _createPartnerTab();
        splitPartnerId.value = partner.id;
        splitFocusSecond.value = false;
        splitRatio.value = 0.5;
        splitMode.value = ExplorerSplitMode.horizontal;
      case ExplorerSplitMode.horizontal:
        splitMode.value = ExplorerSplitMode.vertical;
      case ExplorerSplitMode.vertical:
        exitSplit();
    }
  }

  /// Turns the split off. The partner tab stays open as a regular tab.
  void exitSplit() {
    splitMode.value = ExplorerSplitMode.none;
    splitPartnerId.value = null;
    splitFocusSecond.value = false;
    splitRatio.value = 0.5;
  }

  /// Puts keyboard focus on the given split pane. No-op outside split mode.
  void focusPane({required bool second}) {
    if (!isSplit) return;

    if (splitFocusSecond.value != second) {
      splitFocusSecond.value = second;
    }
    focusedController.keyboardFocusNode.requestFocus();
  }

  /// Toggles keyboard focus between the first and second pane in split view.
  void togglePaneFocus() {
    if (!isSplit) return;
    focusPane(second: !splitFocusSecond.value);
  }

  /// Swaps the positions of the two split panes.
  void swapPanes() {
    if (!isSplit) return;
    final int? partnerId = splitPartnerId.value;
    if (partnerId == null) return;

    final int partnerIndex = tabs.indexWhere((t) => t.id == partnerId);
    if (partnerIndex < 0) return;

    final int currentActiveId = activeTab.id;
    splitPartnerId.value = currentActiveId;
    activeIndex.value = partnerIndex;
    splitFocusSecond.value = !splitFocusSecond.value;
    focusedController.keyboardFocusNode.requestFocus();
  }

  /// Docks the tab at [index] into the pane that does not currently hold it.
  /// When the split is off, this tab becomes the partner pane and gains focus
  /// while the previously active tab keeps pane one.
  void moveTabToOtherPane(int index) {
    if (index < 0 || index >= tabs.length) return;

    if (!isSplit) {
      if (activeIndex.value != index) {
        splitPartnerId.value = tabs[index].id;
        splitRatio.value = 0.5;
        splitMode.value = ExplorerSplitMode.horizontal;
      } else {
        // Moving the active tab itself: duplicate it as pane two instead, so
        // pane one does not collapse.
        splitPartnerId.value = _createPartnerTab().id;
        splitRatio.value = 0.5;
        splitMode.value = ExplorerSplitMode.horizontal;
        splitFocusSecond.value = false;
        return;
      }
    } else if (activeTab.id != tabs[index].id &&
        tabs[index].id == splitPartnerId.value) {
      // The partner tab swaps into pane one.
      swapPanes();
      return;
    } else if (activeTab.id == tabs[index].id) {
      swapPanes();
      return;
    }

    // A background tab takes over pane two; the previous partner stays open.
    splitPartnerId.value = tabs[index].id;
    splitFocusSecond.value = true;
    focusedController.keyboardFocusNode.requestFocus();
  }

  /// Opens [path] in the other split pane, enabling split mode if not already active.
  void openInOtherPane(String path) {
    if (!isSplit) {
      final ExplorerTab partner = addTab(path: path, activate: false);
      splitPartnerId.value = partner.id;
      splitFocusSecond.value = true;
      splitRatio.value = 0.5;
      splitMode.value = ExplorerSplitMode.horizontal;
      partner.controller.keyboardFocusNode.requestFocus();
    } else {
      if (splitFocusSecond.value) {
        activeController.navigateTo(path);
        focusPane(second: false);
      } else {
        final ExplorerTab? partner = partnerTab;
        if (partner != null) {
          partner.controller.navigateTo(path);
        } else {
          final ExplorerTab newPartner = addTab(path: path, activate: false);
          splitPartnerId.value = newPartner.id;
        }
        focusPane(second: true);
      }
    }
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    if (isSplit) {
      final int? partnerId = splitPartnerId.value;
      if (partnerId != null && tabs[index].id == partnerId) {
        focusPane(second: true);
        return;
      }

      if (activeIndex.value == index) {
        focusPane(second: false);
        return;
      }

      // In split view, selecting another tab rebinds the currently focused pane.
      if (splitFocusSecond.value) {
        splitPartnerId.value = tabs[index].id;
        focusedController.keyboardFocusNode.requestFocus();
        return;
      }
    } else if (activeIndex.value == index) {
      return;
    }

    activeIndex.value = index;
    splitFocusSecond.value = false;
  }

  /// Cycles between tabs. [delta] of `1` goes forward, `-1` backward, wrapping
  /// around at both ends.
  void selectRelative(int delta) {
    if (tabs.length < 2) return;

    final int count = tabs.length;
    final int next = (activeIndex.value + delta) % count;
    activeIndex.value = next < 0 ? next + count : next;
    splitFocusSecond.value = false;
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

    if (isSplit) {
      if (tab.id == splitPartnerId.value ||
          tabs.length < 2 ||
          activeTab.id == splitPartnerId.value) {
        exitSplit();
      }
    }
  }

  void closeActiveTab() {
    if (isSplit && splitFocusSecond.value) {
      final int partnerIdx =
          tabs.indexWhere((t) => t.id == splitPartnerId.value);
      if (partnerIdx >= 0) {
        closeTab(partnerIdx);
        return;
      }
    }
    closeTab(activeIndex.value);
  }

  void closeOtherTabs(int index) {
    if (index < 0 || index >= tabs.length) return;

    for (int i = tabs.length - 1; i >= 0; i--) {
      if (i == index) continue;

      final ExplorerTab tab = tabs.removeAt(i);
      tab.controller.onDelete();
    }

    activeIndex.value = 0;

    if (isSplit) {
      exitSplit();
    }
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

    if (isSplit &&
        (tabs.length < 2 ||
            partnerTab == null ||
            activeTab.id == splitPartnerId.value)) {
      exitSplit();
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
