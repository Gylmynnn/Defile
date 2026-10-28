import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/file_explorer_controller.dart';
import 'context_menu.dart';
import 'hover_region.dart';

/// Browser-style strip listing every open tab with quick actions to switch,
/// close and open new ones. Inactive tabs are kept as controllers only; the
/// active tab is the sole explorer subtree rendered at any time.
class ExplorerTabBar extends StatefulWidget {
  const ExplorerTabBar({super.key});

  static const double height = 36;
  static const double tabWidth = 172;

  @override
  State<ExplorerTabBar> createState() => _ExplorerTabBarState();
}

class _ExplorerTabBarState extends State<ExplorerTabBar> {
  static const Duration _doubleTapWindow = Duration(milliseconds: 400);
  static const double _doubleTapSlop = 24;
  // The strip is rebuilt when switching tabs (part of the keyed explorer
  // body), so it starts scrolled to the active tab instead of at the origin.
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset:
        (Get.find<ExplorerTabsController>().activeIndex.value *
                ExplorerTabBar.tabWidth)
            .toDouble(),
  );
  late final Worker _activeWorker;

  Offset? _lastEmptyTapPosition;
  DateTime? _lastEmptyTapTime;

  ExplorerTabsController get _tabs => Get.find<ExplorerTabsController>();

  @override
  void initState() {
    super.initState();
    _activeWorker = ever<int>(_tabs.activeIndex, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveTab());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.jumpTo(
        _scrollController.offset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    _activeWorker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveTab() {
    if (!_scrollController.hasClients) return;

    final int index = _tabs.activeIndex.value;
    final double targetOffset = (index * ExplorerTabBar.tabWidth).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePointerSignal(PointerSignalEvent signal) {
    if (signal is PointerScrollEvent && _scrollController.hasClients) {
      final double delta = signal.scrollDelta.dy != 0
          ? signal.scrollDelta.dy
          : signal.scrollDelta.dx;

      final double newOffset = (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(newOffset);
    }
  }

  void _showEmptyContextMenu(BuildContext context, Offset position) {
    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: CupertinoIcons.add,
            label: 'New Tab',
            shortcut: 'Ctrl+T',
            onSelected: () => _tabs.addTab(),
          ),
        ),
        if (_tabs.canReopenClosedTab)
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: CupertinoIcons.arrow_counterclockwise,
              label: 'Reopen Closed Tab',
              shortcut: 'Ctrl+Shift+T',
              onSelected: () => _tabs.reopenClosedTab(),
            ),
          ),
      ],
    );
  }

  /// Empty-area behavior, resolved manually with a [Listener] instead of a
  /// [GestureDetector] because its recognizers (double tap) would compete in
  /// the gesture arena with the tab tap handlers above it.
  ///
  /// - Secondary press opens the empty-area context menu.
  /// - Two quick primary presses open a new tab, mirroring the browser
  ///   double-click on the empty strip.
  ///
  /// Presses landing on a rendered tab are skipped: tabs report their own
  /// taps through their own gesture detectors.
  void _handleStripPointerDown(PointerDownEvent event) {
    if (_isOverTab(event.position)) return;

    if (event.buttons == kSecondaryButton) {
      _showEmptyContextMenu(context, event.position);
      return;
    }

    if (event.buttons == kPrimaryButton) {
      final Offset position = event.position;
      final DateTime now = DateTime.now();
      final DateTime? last = _lastEmptyTapTime;
      final Offset? lastPosition = _lastEmptyTapPosition;

      _lastEmptyTapTime = now;
      _lastEmptyTapPosition = position;

      if (last == null ||
          lastPosition == null ||
          now.difference(last) > _doubleTapWindow ||
          (position - lastPosition).distance > _doubleTapSlop) {
        return;
      }

      _lastEmptyTapTime = null;
      _lastEmptyTapPosition = null;
      _tabs.addTab();
    }
  }

  /// Whether [globalPosition] falls on a rendered tab. Tabs extend from the
  /// strip origin, shifted left by the current scroll offset.
  bool _isOverTab(Offset globalPosition) {
    if (_tabs.tabs.isEmpty) return false;
    if (!_scrollController.hasClients) return false;

    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached) return false;

    final double localX = object.globalToLocal(globalPosition).dx;

    return localX <
        _tabs.tabs.length * ExplorerTabBar.tabWidth - _scrollController.offset;
  }

  void _showTabContextMenu(BuildContext context, int index, Offset position) {
    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: CupertinoIcons.add,
            label: 'New Tab',
            shortcut: 'Ctrl+T',
            onSelected: () => _tabs.addTab(),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.copy_outlined,
            label: 'Duplicate Tab',
            onSelected: () => _tabs.duplicateTab(index),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.splitscreen,
            label: _tabs.isSplit ? 'Move to Other Pane' : 'Open in Split View',
            onSelected: () => _tabs.moveTabToOtherPane(index),
          ),
        ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: CupertinoIcons.xmark,
            label: 'Close Tab',
            shortcut: 'Ctrl+W',
            enabled: _tabs.canCloseTabs,
            onSelected: () => _tabs.closeTab(index),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.close_fullscreen_outlined,
            label: 'Close Other Tabs',
            enabled: _tabs.canCloseTabs,
            onSelected: () => _tabs.closeOtherTabs(index),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.arrow_forward,
            label: 'Close Tabs to the Right',
            enabled: index < _tabs.tabs.length - 1,
            onSelected: () => _tabs.closeTabsToTheRight(index),
          ),
        ),
        if (_tabs.canReopenClosedTab) ...[
          ContextMenuSeparator(),
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: CupertinoIcons.arrow_counterclockwise,
              label: 'Reopen Closed Tab',
              shortcut: 'Ctrl+Shift+T',
              onSelected: () => _tabs.reopenClosedTab(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ExplorerTabBar.height,
      padding: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: context.colors.windowDeep,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          // Takes all remaining space so tabs only scroll once they truly
          // overflow; the quick action sits at the right edge.
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: _handlePointerSignal,
              onPointerDown: _handleStripPointerDown,
              child: Obx(() {
                final List<ExplorerTab> tabs = _tabs.tabs;
                final int activeIndex = _tabs.activeIndex.value;

                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int index = 0; index < tabs.length; index++) ...[
                        () {
                          final ExplorerTab t = tabs[index];
                          final bool isFirstPane = index == activeIndex;
                          final bool isSecondPane =
                              _tabs.isSplit && t.id == _tabs.splitPartnerId.value;
                          final bool isVisibleInSplit =
                              isFirstPane || isSecondPane;
                          final bool isFocused = _tabs.isSplit
                              ? (_tabs.splitFocusSecond.value
                                  ? isSecondPane
                                  : isFirstPane)
                              : isFirstPane;

                          return _TabItem(
                            key: ValueKey(t.id),
                            tab: t,
                            active: isFocused,
                            dimmed: _tabs.isSplit && !isVisibleInSplit,
                            // Pane number badge: 1 or 2 when the tab is docked
                            // into a split pane, 0 when not docked.
                            paneBadge: isVisibleInSplit
                                ? (isFirstPane ? 1 : 2)
                                : 0,
                            badgeHighlighted: isFocused,
                            canClose: _tabs.canCloseTabs,
                            onSelect: () => _tabs.selectTab(index),
                            onClose: () => _tabs.closeTab(index),
                            onContextMenu: (position) =>
                                _showTabContextMenu(context, index, position),
                          );
                        }(),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
          _NewTabButton(onTap: () => _tabs.addTab()),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.tab,
    required this.active,
    this.dimmed = false,
    this.paneBadge = 0,
    this.badgeHighlighted = false,
    required this.canClose,
    required this.onSelect,
    required this.onClose,
    required this.onContextMenu,
  });

  /// Rounded on all corners: the active tab reads as a single raised pill,
  /// inset within the strip like classic terminal tabs.
  static const BorderRadius shape = BorderRadius.all(Radius.circular(6));

  final ExplorerTab tab;
  final bool active;

  /// Background tabs during split view render at reduced opacity.
  final bool dimmed;

  /// Pane number rendered on the pill when the tab docks into a split pane
  /// (1 = first pane, 2 = partner pane, 0 = not docked).
  final int paneBadge;

  /// Whether [paneBadge] renders in the accent color (focused pane) or muted.
  final bool badgeHighlighted;
  final bool canClose;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final void Function(Offset position) onContextMenu;

  IconData _iconFor(FileExplorerController controller) {
    switch (controller.location.value) {
      case ExplorerLocation.recent:
        return CupertinoIcons.time;
      case ExplorerLocation.trash:
        return CupertinoIcons.trash;
      case ExplorerLocation.directory:
        if (controller.currentPath.value.isEmpty ||
            controller.currentPath.value == controller.homePath.value) {
          return CupertinoIcons.house;
        }
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        final Color background = active
            ? context.colors.surface
            : hovered
            ? context.colors.hover
            : Colors.transparent;

        Widget child = Obx(() {
          final String title = tab.controller.tabTitle;
          final String tooltip = tab.controller.currentPath.value.isNotEmpty
              ? tab.controller.currentPath.value
              : title;
          final IconData icon = _iconFor(tab.controller);

          return Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 600),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect,
              onTertiaryTapUp: (_) {
                if (canClose) onClose();
              },
              onSecondaryTapDown: (details) =>
                  onContextMenu(details.globalPosition),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: ExplorerTabBar.tabWidth,
                height: ExplorerTabBar.height,
                padding: const EdgeInsets.only(left: 12, right: 6),
                margin: const EdgeInsets.only(top: 3, bottom: 3, right: 2),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: _TabItem.shape,
                  // Hairline separator between resting tabs only; a tab
                  // holding paint (active or hovered) doesn't need one.
                  // border: !active && !hovered
                  //     ? Border(right: BorderSide(color: context.colors.divider))
                  //     : null,
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: 14,
                        color: active
                            ? (tab.controller.location.value ==
                                      ExplorerLocation.directory
                                  ? context.colors.folder
                                  : context.colors.accent)
                            : context.colors.textFaint,
                      ),
                    ),
                    if (paneBadge > 0) ...[
                      const SizedBox(width: 5),
                      _PaneBadge(
                        number: paneBadge,
                        highlighted: badgeHighlighted,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? context.colors.textStrong
                              : context.colors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (canClose && (active || hovered))
                      HoverRegion(
                        cursor: SystemMouseCursors.click,
                        builder: (context, closeHovered) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onClose,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: closeHovered
                                    ? context.colors.hover
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                CupertinoIcons.xmark,
                                size: 10.5,
                                color: closeHovered
                                    ? context.colors.textPrimary
                                    : context.colors.textFaint,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          );
        });

        if (!dimmed) return child;

        return Opacity(opacity: 0.55, child: child);
      },
    );
  }
}

/// Tiny pane number chip on tabs docked into a split pane.
class _PaneBadge extends StatelessWidget {
  const _PaneBadge({required this.number, required this.highlighted});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color foreground = highlighted
        ? context.colors.accentContent
        : context.colors.textFaint;

    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: highlighted
            ? context.colors.accent
            : context.colors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
          color: foreground,
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New tab (Ctrl+T)',
      child: HoverRegion(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              width: 28,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: hovered ? context.colors.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                CupertinoIcons.plus,
                size: 15,
                color: hovered
                    ? context.colors.textPrimary
                    : context.colors.textFaint,
              ),
            ),
          );
        },
      ),
    );
  }
}
