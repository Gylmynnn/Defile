import 'dart:async';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/explorer_tabs_controller.dart';
import '../controllers/file_explorer_controller.dart';
import '../services/theme_service.dart';
import '../utils/app_dialog_route.dart';
import '../utils/app_toast.dart';
import 'widgets/app_dialog.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/context_menu.dart';
import 'widgets/directory_picker_dialog.dart';
import 'widgets/entry_views.dart';
import 'widgets/explorer_scope.dart';
import 'widgets/explorer_status_bar.dart';
import 'widgets/explorer_tab_bar.dart';
import 'widgets/explorer_toolbar.dart';
import 'widgets/open_with_submenu.dart';
import 'widgets/preview_panel.dart';
import 'widgets/properties_dialog.dart';

part 'explorer_page_actions.dart';
part 'explorer_page_extras.dart';

/// Application shell: hosts the tab strip and renders the active tab.
///
/// Only the active explorer subtree is built, so the number of open tabs does
/// not add widget-tree or paint cost. Each tab keeps its own
/// [FileExplorerController] alive, preserving directory, history and
/// selection while switching.
class FileExplorerPage extends StatelessWidget {
  const FileExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          // Tab management
          const SingleActivator(LogicalKeyboardKey.keyT, control: true): () =>
              tabs.addTab(),
          const SingleActivator(LogicalKeyboardKey.keyT, meta: true): () =>
              tabs.addTab(),
          const SingleActivator(
            LogicalKeyboardKey.keyT,
            control: true,
            shift: true,
          ): () => tabs.reopenClosedTab(),
          const SingleActivator(
            LogicalKeyboardKey.keyT,
            meta: true,
            shift: true,
          ): () => tabs.reopenClosedTab(),
          const SingleActivator(LogicalKeyboardKey.keyW, control: true):
              tabs.closeActiveTab,
          const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
              tabs.closeActiveTab,
          const SingleActivator(LogicalKeyboardKey.tab, control: true):
              () => tabs.selectRelative(1),
          const SingleActivator(
            LogicalKeyboardKey.tab,
            control: true,
            shift: true,
          ): () => tabs.selectRelative(-1),
          // Tab direct selection (1-9)
          const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
              tabs.selectTab(0),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
              tabs.selectTab(1),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
              tabs.selectTab(2),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
              tabs.selectTab(3),
          const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
              tabs.selectTab(4),
          const SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
              tabs.selectTab(5),
          const SingleActivator(LogicalKeyboardKey.digit7, control: true): () =>
              tabs.selectTab(6),
          const SingleActivator(LogicalKeyboardKey.digit8, control: true): () =>
              tabs.selectTab(7),
          const SingleActivator(LogicalKeyboardKey.digit9, control: true): () =>
              tabs.selectTab(tabs.tabs.length - 1),
          const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
              tabs.selectTab(0),
          const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
              tabs.selectTab(1),
          const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
              tabs.selectTab(2),
          const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
              tabs.selectTab(3),
          const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
              tabs.selectTab(4),
          const SingleActivator(LogicalKeyboardKey.digit6, meta: true): () =>
              tabs.selectTab(5),
          const SingleActivator(LogicalKeyboardKey.digit7, meta: true): () =>
              tabs.selectTab(6),
          const SingleActivator(LogicalKeyboardKey.digit8, meta: true): () =>
              tabs.selectTab(7),
          const SingleActivator(LogicalKeyboardKey.digit9, meta: true): () =>
              tabs.selectTab(tabs.tabs.length - 1),
        },
        child: Obx(() {
          final FileExplorerController active = tabs.activeController;

          return ExplorerScope(
            controller: active,
            child: ExplorerBody(key: ValueKey(tabs.activeTab.id)),
          );
        }),
      ),
    );
  }
}

class ExplorerBody extends StatefulWidget {
  const ExplorerBody({super.key});

  @override
  State<ExplorerBody> createState() => _ExplorerBodyState();
}

class _ExplorerBodyState extends State<ExplorerBody> {
  final GlobalKey _selectionLayerKey = GlobalKey();

  FileExplorerController? _controller;
  FileExplorerController get controller => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ExplorerScope.of(context);
  }

  bool _entryPressActive = false;
  String? _pendingOpenPath;

  bool _bandCandidate = false;
  bool _bandActive = false;
  Offset? _bandStart;
  Offset? _bandCurrent;
  final ValueNotifier<Rect?> _bandRect = ValueNotifier<Rect?>(null);
  Set<String> _bandBase = <String>{};
  final Map<String, Rect> _dragRects = <String, Rect>{};
  bool _bandUpdateScheduled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _openSelected,
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              _renameSelected(context),
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true):
              _copySelected,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true):
              _cutSelected,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.keyA, control: true):
              _selectAll,
          const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              _refresh,
          const SingleActivator(LogicalKeyboardKey.f5): _refresh,
          const SingleActivator(LogicalKeyboardKey.f4): _openTerminal,
          const SingleActivator(LogicalKeyboardKey.keyB, control: true):
              _toggleSidebar,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _startSearch,
          const SingleActivator(LogicalKeyboardKey.delete, shift: true):
              _deleteSelectedPermanently,
          const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
              _goToParent,
          const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
            shift: true,
          ): () =>
              _newFolder(context),
        },
        child: Focus(
          focusNode: controller.keyboardFocusNode,
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final Duration duration = Get.isRegistered<ThemeService>()
                    ? Get.find<ThemeService>().animationDuration
                    : Duration.zero;

                return AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: controller.showSidebar.value ? 178 : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 178,
                      maxWidth: 178,
                      child: AppSidebar(),
                    ),
                  ),
                );
              }),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.colors.divider,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              ExplorerToolbar(),
                              const ExplorerTabBar(),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: _handleBackgroundTap,
                                        onSecondaryTapUp: (details) =>
                                            _showBackgroundMenu(
                                              context,
                                              details.globalPosition,
                                            ),
                                        child: Obx(
                                          () => _buildContent(context),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Listener(
                                        key: _selectionLayerKey,
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: _handleBandDown,
                                        onPointerMove: _handleBandMove,
                                        onPointerUp: _handleBandUp,
                                        onPointerCancel: _handleBandUp,
                                        child: IgnorePointer(
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _SelectionBandPainter(
                                                _bandRect,
                                                context.colors,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ExplorerStatusBar(),
                            ],
                          ),
                        ),
                        PreviewPanel(availableWidth: constraints.maxWidth),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _keyboardBlocked => controller.isSearching.value;

  @override
  void dispose() {
    _bandRect.dispose();
    super.dispose();
  }

  void _handleBackgroundTap() {
    _pendingOpenPath = null;
    controller.clearSelection();
  }

  void _handleBandDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;

    _bandCandidate = true;
    _bandStart = event.localPosition;
    _bandCurrent = event.localPosition;
  }

  void _handleBandMove(PointerMoveEvent event) {
    if (!_bandCandidate || _bandStart == null) return;

    if (_entryPressActive) {
      _bandCandidate = false;
      return;
    }

    _bandCurrent = event.localPosition;

    if (!_bandActive && (_bandCurrent! - _bandStart!).distance < 4) return;

    if (!_bandActive) {
      _bandActive = true;
      _dragRects.clear();

      final HardwareKeyboard keyboard = HardwareKeyboard.instance;
      _bandBase = keyboard.isControlPressed || keyboard.isMetaPressed
          ? controller.selection.map((entry) => entry.path).toSet()
          : <String>{};

      _collectDragRects();
    }

    _scheduleBandUpdate();
  }

  void _scheduleBandUpdate() {
    if (_bandUpdateScheduled) return;

    _bandUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _bandUpdateScheduled = false;
      if (!mounted || !_bandActive) return;
      _applyBandSelection();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _handleBandUp(PointerEvent event) {
    _bandCandidate = false;
    _entryPressActive = false;

    if (!_bandActive) return;

    _applyBandSelection();
    _bandActive = false;
    _bandUpdateScheduled = false;
    _dragRects.clear();

    _bandRect.value = null;
  }

  void _collectDragRects() {
    final RenderBox? layer =
        _selectionLayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (layer == null) return;

    for (final entry in controller.visibleEntries) {
      final RenderObject? object = entryTileKey(entry.path).currentContext
          ?.findRenderObject();

      if (object is! RenderBox || !object.attached) continue;

      _dragRects[entry.path] =
          object.localToGlobal(Offset.zero, ancestor: layer) & object.size;
    }
  }

  void _applyBandSelection() {
    final Rect band = Rect.fromPoints(_bandStart!, _bandCurrent!);
    final Set<String> paths = <String>{..._bandBase};

    for (final tile in _dragRects.entries) {
      if (tile.value.overlaps(band)) paths.add(tile.key);
    }

    _bandRect.value = band;

    final List<rust.FileEntry> next = controller.visibleEntries
        .where((entry) => paths.contains(entry.path))
        .toList();

    if (_matchesSelection(next)) return;
    controller.selection.assignAll(next);
  }

  bool _matchesSelection(List<rust.FileEntry> next) {
    final List<rust.FileEntry> current = controller.selection;
    if (current.length != next.length) return false;
    for (int i = 0; i < next.length; i++) {
      if (current[i].path != next[i].path) return false;
    }
    return true;
  }

  Future<void> _openSelected() async {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection.toList();
    if (selected.isEmpty) return;

    for (final entry in selected) {
      await controller.openFile(entry);
    }
  }

  void _renameSelected(BuildContext context) {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.length != 1) return;

    _showRenameDialog(context, selected.first);
  }

  Future<void> _deleteSelected() async {
    if (_keyboardBlocked) return;

    await _removeSelection();
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_keyboardBlocked) return;

    await _removeSelection(permanent: true);
  }

  Future<void> _removeSelection({bool permanent = false}) async {
    final List<rust.FileEntry> selected = controller.selection.toList();
    if (selected.isEmpty) return;

    if (permanent || controller.isCurrentInTrash) {
      final bool confirmed = await _confirm(
        title: 'Delete permanently?',
        message: selected.length == 1
            ? '"${selected.first.name}" will be permanently deleted. This action cannot be undone.'
            : '${selected.length} items will be permanently deleted. This action cannot be undone.',
        confirmLabel: 'Delete Permanently',
      );

      if (!confirmed) return;

      await controller.deletePermanently(selected);
      return;
    }

    await controller.trashEntries(selected);
  }

  void _copySelected() {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.isEmpty) return;

    controller.copyToClipboard(selected.toList());
  }

  void _cutSelected() {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.isEmpty) return;

    controller.cutToClipboard(selected.toList());
  }

  void _paste() {
    if (_keyboardBlocked) return;
    controller.pasteIntoCurrentDirectory();
  }

  void _selectAll() {
    if (_keyboardBlocked) return;
    controller.selectAll();
  }

  void _clearSelection() {
    if (_keyboardBlocked) return;
    _pendingOpenPath = null;
    controller.clearSelection();
  }

  void _refresh() {
    if (_keyboardBlocked) return;
    controller.refreshDirectory();
  }

  void _toggleSidebar() {
    if (_keyboardBlocked) return;
    controller.toggleSidebar();
  }

  void _startSearch() {
    controller.startSearch();
    controller.searchFocusNode.requestFocus();
  }

  void _openTerminal() {
    if (_keyboardBlocked) return;
    controller.openTerminal();
  }

  void _goToParent() {
    if (_keyboardBlocked) return;
    controller.goToParent();
  }

  void _newFolder(BuildContext context) {
    if (_keyboardBlocked) return;
    _showCreateFolderDialog(context);
  }

  Widget _buildContent(BuildContext context) {
    final String? error = controller.errorMessage.value;
    if (error != null) {
      return _buildError(error);
    }

    final List<rust.FileEntry> entries = controller.visibleEntries;
    if (entries.isEmpty) {
      if (controller.isLoading.value) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }

      return _buildEmpty();
    }

    void openMenu(rust.FileEntry entry, Offset position) {
      if (!controller.isSelected(entry)) {
        controller.selectOnly(entry);
      }

      _showEntryMenu(context, entry, position);
    }

    final Widget view = switch (controller.viewMode.value) {
      ExplorerViewMode.grid => EntryGridView(
        entries: entries,
        selectedPaths: controller.selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
        onMiddleClick: _handleEntryMiddleClick,
        dragEntries: _dragEntriesFor,
        canDrop: controller.canDropEntries,
        onDrop: _moveEntriesTo,
      ),
      ExplorerViewMode.list => EntryListView(
        entries: entries,
        selectedPaths: controller.selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
        onMiddleClick: _handleEntryMiddleClick,
        dragEntries: _dragEntriesFor,
        canDrop: controller.canDropEntries,
        onDrop: _moveEntriesTo,
      ),
      ExplorerViewMode.compact => EntryCompactView(
        entries: entries,
        selectedPaths: controller.selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
        onMiddleClick: _handleEntryMiddleClick,
        dragEntries: _dragEntriesFor,
        canDrop: controller.canDropEntries,
        onDrop: _moveEntriesTo,
      ),
    };

    return _LoadingShroud(loading: controller.isLoading.value, child: view);
  }

  void _handleEntryMiddleClick(rust.FileEntry entry) {
    if (entry.isDirectory && Get.isRegistered<ExplorerTabsController>()) {
      Get.find<ExplorerTabsController>().addTab(path: entry.path);
    }
  }

  void _handleEntryPress(rust.FileEntry entry) {
    _entryPressActive = true;

    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      controller.toggleSelection(entry);
      _pendingOpenPath = null;
      return;
    }

    if (keyboard.isShiftPressed) {
      controller.selectRangeTo(entry);
      _pendingOpenPath = null;
      return;
    }

    if (!controller.isSelected(entry)) {
      controller.selectOnly(entry);
      _pendingOpenPath = null;
      return;
    }

    _pendingOpenPath = controller.selection.length == 1 ? entry.path : null;
  }

  void _handleEntryTap(rust.FileEntry entry) {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return;
    }

    if (_pendingOpenPath == entry.path) {
      _pendingOpenPath = null;
      controller.openFile(entry);
      return;
    }

    if (controller.selection.length > 1) {
      controller.selectOnly(entry);
      _pendingOpenPath = entry.path;
    }
  }

  List<rust.FileEntry> _dragEntriesFor(rust.FileEntry entry) {
    if (controller.isSelected(entry) && controller.selection.length > 1) {
      return controller.selectionSnapshot;
    }

    return <rust.FileEntry>[entry];
  }

  void _moveEntriesTo(
    List<rust.FileEntry> entries,
    String destinationDirectory,
  ) {
    if (!controller.canDropEntries(entries, destinationDirectory)) return;

    controller.moveEntries(
      entries: entries,
      destinationDirectory: destinationDirectory,
    );
  }

  void _handleEntryOpen(rust.FileEntry entry) {
    _pendingOpenPath = null;
    controller.selectOnly(entry);
    controller.openFile(entry);
  }
}
