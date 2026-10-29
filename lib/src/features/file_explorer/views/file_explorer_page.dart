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
import '../controllers/portal_pick_controller.dart';
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
/// Only the visible pane subtree is built, so the number of open tabs does not
/// add widget-tree or paint cost. Each tab keeps its own
/// [FileExplorerController] alive, preserving directory, history and
/// selection while switching. In split view the page scope resolves to the
/// focused pane's controller, so the shared sidebar and preview panel follow
/// whichever pane the user works in.
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
          // Split pane management
          const SingleActivator(LogicalKeyboardKey.f3): tabs.cycleSplitMode,
          const SingleActivator(LogicalKeyboardKey.backslash, control: true):
              tabs.cycleSplitMode,
          const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
              tabs.cycleSplitMode,
          const SingleActivator(LogicalKeyboardKey.f6): tabs.togglePaneFocus,
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
        child: _LayoutHost(tabs: tabs),
      ),
    );
  }
}

/// Chooses between the single body and the split layout, and owns the split
/// exit transition: when split view is turned off, a snapshot of the split
/// layout stays mounted one beat while its second pane glides shut and the
/// shared top bar collapses — then the single body takes over. Only one
/// layout is ever mounted, so rapid toggling cannot duplicate elements.
class _LayoutHost extends StatefulWidget {
  const _LayoutHost({required this.tabs});

  final ExplorerTabsController tabs;

  @override
  State<_LayoutHost> createState() => _LayoutHostState();
}

class _LayoutHostState extends State<_LayoutHost> {
  ExplorerTab? _exitFirst;
  ExplorerTab? _exitSecond;
  ExplorerSplitMode? _exitMode;
  bool _exiting = false;
  Timer? _exitTimer;

  void _rememberSplit() {
    final ExplorerTabsController tabs = widget.tabs;
    _exitFirst = tabs.activeTab;
    _exitSecond = tabs.partnerTab;
    _exitMode = tabs.splitMode.value;
  }

  void _clearExit() {
    _exitTimer?.cancel();
    _exitTimer = null;
    _exiting = false;
    _exitFirst = null;
    _exitSecond = null;
    _exitMode = null;
  }

  void _beginExit() {
    _exiting = true;
    final Duration glide = Get.isRegistered<ThemeService>()
        ? Get.find<ThemeService>().animationDuration * 1.4
        : Duration.zero;
    _exitTimer?.cancel();
    _exitTimer = Timer(glide + const Duration(milliseconds: 50), () {
      if (mounted) setState(_clearExit);
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerTabsController tabs = widget.tabs;

    // ExplorerScope must live INSIDE the Obx: it has to pick up the freshly
    // focused controller every time the active tab / pane changes, otherwise
    // the body would keep showing the controller it was first built with.
    return Obx(() {
      final FileExplorerController focused = tabs.focusedController;

      return ExplorerScope(
        controller: focused,
        child: () {
          if (tabs.isSplit) {
            _clearExit();
            _rememberSplit();
            // Key on the MODE only: switching tabs (or the focused pane)
            // updates this layout in place — the glide should replay solely
            // when the split mode itself is toggled.
            return _SplitLayout(
              key: ValueKey('split:${tabs.splitMode.value}'),
            );
          }

          if (_exitMode != null && _exitFirst != null && _exitSecond != null) {
            // Cut the exit short if a pane's tab was closed mid-glide.
            final bool alive = tabs.tabs.contains(_exitFirst) &&
                tabs.tabs.contains(_exitSecond);
            if (alive) {
              if (!_exiting) {
                // First frame after leaving split: the snapshot is already
                // mounted below; start the exit clock after this frame so the
                // state machine settles once the glide finishes.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(_beginExit);
                });
              }
              return _SplitLayout(
                key: ValueKey('split-exit:$_exitMode'),
                exiting: true,
                exitFirst: _exitFirst,
                exitSecond: _exitSecond,
                exitMode: _exitMode,
              );
            }
            _clearExit();
          }

          return ExplorerBody(key: ValueKey(tabs.activeTab.id));
        }(),
      );
    });
  }
}

/// Sidebar rail shared by the single and split layouts. Slides away when the
/// current controller hides it.
class _SidebarRail extends StatelessWidget {
  const _SidebarRail({required this.controller});

  final FileExplorerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Duration duration = Get.isRegistered<ThemeService>()
          ? Get.find<ThemeService>().animationDuration
          : Duration.zero;
      final bool expanded = controller.showSidebar.value;

      return AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        // Collapsing keeps an icon rail instead of hiding the sidebar
        // entirely, so quick access stays one click away.
        width: expanded ? 178 : 52,
        child: ClipRect(child: AppSidebar(collapsed: !expanded)),
      );
    });
  }
}

/// Layout for a single (unsplit) tab: toolbar, tab strip, content, status bar
/// and the preview panel to the right.
class ExplorerBody extends StatelessWidget {
  const ExplorerBody({super.key});

  @override
  Widget build(BuildContext context) {
    final FileExplorerController controller = ExplorerScope.of(context);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarRail(controller: controller),
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
                            child: _EntryContentArea(paneOwner: controller),
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
    );
  }
}

/// Vertical (stacked) or horizontal (side by side) split of the content area
/// between the active tab and its partner tab. The tab strip, sidebar and
/// preview panel stay shared above / beside the two panes.
class _SplitLayout extends StatelessWidget {
  const _SplitLayout({
    super.key,
    this.exiting = false,
    this.exitFirst,
    this.exitSecond,
    this.exitMode,
  });

  /// When true, this instance is a snapshot animating shut after split view
  /// was turned off: the second pane glides closed and the shared top bar
  /// collapses before the single body takes over.
  final bool exiting;

  /// Panes and orientation captured at exit time — the tabs controller has
  /// already undocked the partner by then, so the snapshot pins them.
  final ExplorerTab? exitFirst;
  final ExplorerTab? exitSecond;
  final ExplorerSplitMode? exitMode;

  /// Shared instances keep a stable identity across rebuilds. TweenAnimation
  /// Builder restarts from [Tween.begin] whenever it receives a different
  /// tween, so a fresh instance here would snap the glide back to its start
  /// on every parent rebuild (the topbar "pop back" glitch).
  static final Tween<double> _enterGlide = Tween<double>(
    begin: 0.0,
    end: 1.0,
  );
  static final Tween<double> _exitGlide = Tween<double>(
    begin: 1.0,
    end: 0.0,
  );

  @override
  Widget build(BuildContext context) {
    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();
    final ExplorerTab? partner = tabs.partnerTab;

    // Defensive: split mode without a live partner renders a single body.
    if (!exiting && partner == null) {
      return ExplorerBody(key: ValueKey(tabs.activeTab.id));
    }

    final ExplorerTab first = exiting
        ? (exitFirst ?? tabs.activeTab)
        : tabs.activeTab;
    final ExplorerTab second = exiting
        ? (exitSecond ?? tabs.activeTab)
        : partner!;
    final bool vertical = exiting
        ? (exitMode ?? ExplorerSplitMode.horizontal) ==
              ExplorerSplitMode.vertical
        : tabs.splitMode.value == ExplorerSplitMode.vertical;

    // Entrance glide: the second pane eases open from its collapsed minimum
    // to the saved ratio. Exit glide: it eases shut the same way. Real layout
    // motion — the same movement as dragging the divider — so it stays smooth
    // on this heavy widget tree (no opacity repaints).
    final Duration glide = Get.isRegistered<ThemeService>()
        ? Get.find<ThemeService>().animationDuration * 1.4
        : Duration.zero;

    Widget panes(double t) {
      return LayoutBuilder(
        builder: (context, paneConstraints) {
          final double totalDimension = vertical
              ? paneConstraints.maxHeight
              : paneConstraints.maxWidth;

          return Obx(() {
            final double ratio = tabs.splitRatio.value;
            // 0.998 keeps the second pane alive at a sliver, so the exit ends
            // flush with the single-body layout instead of a hard cut.
            final double shownRatio = 0.998 + (ratio - 0.998) * t;
            final int flex1 = exiting
                ? (shownRatio * 1000).round().clamp(2, 998)
                : (shownRatio * 1000).toInt().clamp(150, 850);
            final int flex2 = 1000 - flex1;

            final Widget firstPane = Flexible(
              flex: flex1,
              child: _SplitPane(
                tab: first,
                second: false,
                forceVertical: vertical,
              ),
            );

            final Widget divider = _PaneDivider(
              axis: vertical ? Axis.vertical : Axis.horizontal,
              onDrag: (delta) {
                if (totalDimension > 0) {
                  tabs.updateSplitRatio(delta / totalDimension);
                }
              },
              onDoubleTap: tabs.resetSplitRatio,
            );

            final Widget secondPane = Flexible(
              flex: flex2,
              child: _SplitPane(
                tab: second,
                second: true,
                forceVertical: vertical,
              ),
            );

            // Small gutter so each pane's focus frame has room at the outer
            // edges instead of being clipped by the window / tab strip.
            return Padding(
              padding: const EdgeInsets.all(2.5),
              child: vertical
                  ? Column(
                      children: [
                        firstPane,
                        divider,
                        secondPane,
                      ],
                    )
                  : Row(
                      children: [
                        firstPane,
                        divider,
                        secondPane,
                      ],
                    ),
            );
          });
        },
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarRail(controller: ExplorerScope.of(context)),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: context.colors.divider,
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: exiting ? _exitGlide : _enterGlide,
              duration: glide,
              curve: Curves.easeOutCubic,
              builder: (context, double t, _) => Column(
                children: [
                  // Shared top bar grows in on the way in and collapses with
                  // the exit glide instead of popping.
                  ClipRect(
                    child: Align(
                      heightFactor: t.clamp(0.0, 1.0),
                      alignment: Alignment.topCenter,
                      child: const ExplorerSplitTopBar(),
                    ),
                  ),
                  const ExplorerTabBar(),
                  Expanded(child: panes(t)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pane of the split area: its own toolbar, entry content and status bar,
/// all bound to the pane's tab controller. Shows an accent frame when focused.
class _SplitPane extends StatelessWidget {
  const _SplitPane({required this.tab, required this.second, this.forceVertical});

  final ExplorerTab tab;
  final bool second;

  /// Pins the pane layout orientation. The exit snapshot passes the mode
  /// captured at exit time because the tabs controller has already dropped
  /// back to [ExplorerSplitMode.none] by then.
  final bool? forceVertical;

  @override
  Widget build(BuildContext context) {
    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();

    return ExplorerScope(
      controller: tab.controller,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => tabs.focusPane(second: second),
        child: Obx(() {
          final bool isFocused = tabs.splitFocusSecond.value == second;
          final bool vertical = forceVertical ??
              tabs.splitMode.value == ExplorerSplitMode.vertical;

          // Own preview per pane: below the content in side-by-side split,
          // beside the content in stacked split (reads better at half width
          // vs half height).
          final Widget mainArea = Column(
            children: [
              ExplorerToolbar(compact: true),
              Expanded(
                child: _EntryContentArea(
                  key: ValueKey('pane:${tab.id}'),
                  paneOwner: tab.controller,
                  second: second,
                ),
              ),
              if (!vertical)
                PreviewBottomPanel(
                  availableWidth: 0,
                  enabledOverride: tab.controller.panePreviewEnabled,
                ),
              ExplorerStatusBar(),
            ],
          );

          // foregroundDecoration so pane content (toolbars, status bar) can
          // never paint over the focus frame.
          return Container(
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: isFocused
                    ? context.colors.accent.withValues(alpha: 0.38)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: vertical
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(child: mainArea),
                          PreviewPanel(
                            availableWidth: constraints.maxWidth,
                            enabledOverride:
                                tab.controller.panePreviewEnabled,
                          ),
                        ],
                      );
                    },
                  )
                : mainArea,
          );
        }),
      ),
    );
  }
}

/// Draggable splitter between the two split panes. [axis] is the direction
/// the panes are laid out in: stacked panes (Axis.vertical) get a horizontal divider.
class _PaneDivider extends StatefulWidget {
  const _PaneDivider({
    required this.axis,
    this.onDrag,
    this.onDoubleTap,
  });

  final Axis axis;
  final ValueChanged<double>? onDrag;
  final VoidCallback? onDoubleTap;

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final bool isVertical = widget.axis == Axis.vertical;
    final SystemMouseCursor cursor = isVertical
        ? SystemMouseCursors.resizeRow
        : SystemMouseCursors.resizeColumn;

    final Color dividerColor = (_hovered || _dragging)
        ? context.colors.accent
        : context.colors.divider;

    final Widget line = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      color: dividerColor,
      width: isVertical ? double.infinity : 1,
      height: isVertical ? 1 : double.infinity,
    );

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart: isVertical ? null : (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: isVertical
            ? null
            : (details) => widget.onDrag?.call(details.delta.dx),
        onHorizontalDragEnd: isVertical ? null : (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: isVertical ? null : () => setState(() => _dragging = false),
        onVerticalDragStart: !isVertical ? null : (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: !isVertical
            ? null
            : (details) => widget.onDrag?.call(details.delta.dy),
        onVerticalDragEnd: !isVertical ? null : (_) => setState(() => _dragging = false),
        onVerticalDragCancel: !isVertical ? null : () => setState(() => _dragging = false),
        child: Container(
          width: isVertical ? double.infinity : 9,
          height: isVertical ? 9 : double.infinity,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: line,
        ),
      ),
    );
  }
}

/// The interactive entry area of one tab: view content plus the rubber band
/// selection layer and the keyboard bindings that operate on this pane. In
/// split view each pane owns an instance, and interacting with a pane moves
/// keyboard focus (and the shared preview panel) to it.
class _EntryContentArea extends StatefulWidget {
  const _EntryContentArea({
    super.key,
    required this.paneOwner,
    this.second = false,
  });

  final FileExplorerController paneOwner;

  /// Whether this instance fills the second split pane.
  final bool second;

  @override
  State<_EntryContentArea> createState() => _EntryContentState();
}

class _EntryContentState extends State<_EntryContentArea> {
  final GlobalKey _selectionLayerKey = GlobalKey();

  FileExplorerController get controller => widget.paneOwner;

  @override
  void didUpdateWidget(covariant _EntryContentArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.paneOwner != widget.paneOwner) {
      // The pane was rebound to another tab; drop any in-flight band or
      // double-click state that belongs to the previous controller.
      _entryPressActive = false;
      _bandCandidate = false;
      _bandActive = false;
      _pendingOpenPath = null;
      _dragRects.clear();
      _bandRect.value = null;
    }
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
    return CallbackShortcuts(
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
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
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
        const SingleActivator(LogicalKeyboardKey.f6): _switchPaneFocus,
        const SingleActivator(LogicalKeyboardKey.tab): _switchPaneFocus,
      },
      child: Focus(
        focusNode: controller.keyboardFocusNode,
        autofocus: !widget.second,
        child: Stack(
          children: [
            Positioned.fill(
              child: DragTarget<List<rust.FileEntry>>(
                onWillAcceptWithDetails: (details) {
                  return controller.location.value ==
                          ExplorerLocation.directory &&
                      controller.canDropEntries(
                        details.data,
                        controller.currentPath.value,
                      );
                },
                onAcceptWithDetails: (details) {
                  _notifyPaneFocus();
                  _moveEntriesTo(details.data, controller.currentPath.value);
                },
                builder: (context, candidateData, rejectedData) {
                  final bool isHovering = candidateData.any(
                    (data) =>
                        data != null &&
                        controller.location.value ==
                            ExplorerLocation.directory &&
                        controller.canDropEntries(
                          data,
                          controller.currentPath.value,
                        ),
                  );

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _handleBackgroundTap,
                          onSecondaryTapUp: (details) =>
                              _showBackgroundMenu(context, details.globalPosition),
                          child: Obx(() => _buildContent(context)),
                        ),
                      ),
                      if (isHovering)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.colors.selection
                                    .withValues(alpha: 0.18),
                                border: Border.all(
                                  color: context.colors.accent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
    );
  }

  bool get _keyboardBlocked => controller.isSearching.value;

  @override
  void dispose() {
    _bandRect.dispose();
    super.dispose();
  }

  /// Moves keyboard focus (and the shared preview panel) to this pane when
  /// the user works in it.
  void _notifyPaneFocus() {
    if (!Get.isRegistered<ExplorerTabsController>()) return;

    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();
    if (!tabs.isSplit) return;

    tabs.focusPane(second: widget.second);
  }

  void _switchPaneFocus() {
    if (!Get.isRegistered<ExplorerTabsController>()) return;

    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();
    if (!tabs.isSplit) return;

    tabs.focusPane(second: !widget.second);
  }

  void _handleBackgroundTap() {
    _notifyPaneFocus();
    _pendingOpenPath = null;
    controller.clearSelection();
  }

  void _handleBandDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;

    _notifyPaneFocus();
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
      final RenderObject? object = entryTileKey(
        entry.path,
        owner: controller,
      ).currentContext?.findRenderObject();

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
        paneOwner: controller,
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
        paneOwner: controller,
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
        paneOwner: controller,
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
    _notifyPaneFocus();
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
    _notifyPaneFocus();
    _pendingOpenPath = null;
    controller.selectOnly(entry);
    // In portal-picker mode a double-click acts as the dialog's confirm.
    if (Get.isRegistered<PortalPickController>()) {
      final PortalPickController picker = Get.find<PortalPickController>();
      unawaited(
        picker.tryConfirmWithEntry(entry).then((bool confirmed) {
          if (!confirmed) controller.openFile(entry);
        }),
      );
      return;
    }
    controller.openFile(entry);
  }
}
