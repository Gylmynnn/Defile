import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../services/theme_service.dart';
import 'hover_region.dart';

class ContextMenuAction {
  ContextMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.shortcut,
    this.danger = false,
    this.enabled = true,
    this.submenu,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool danger;
  final bool enabled;
  final VoidCallback onSelected;
  final Widget Function(VoidCallback closeMenu)? submenu;
}

sealed class ContextMenuEntry {
  ContextMenuEntry();
}

class ContextMenuActionEntry extends ContextMenuEntry {
  ContextMenuActionEntry(this.action);

  final ContextMenuAction action;
}

class ContextMenuSeparator extends ContextMenuEntry {
  ContextMenuSeparator();
}

Future<void> showAppContextMenu({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuEntry> entries,
}) {
  final OverlayState overlay = Overlay.of(context);

  const double menuWidth = 248;
  const double edgePadding = 8;

  final RenderObject? overlayObject = overlay.context.findRenderObject();
  final Offset localPosition = overlayObject is RenderBox
      ? overlayObject.globalToLocal(position)
      : position;

  double estimatedHeight = 12;
  for (final entry in entries) {
    estimatedHeight += entry is ContextMenuSeparator ? 9 : 30;
  }

  final Size screen = overlay.context.size ?? const Size(1920, 1080);
  final double left = localPosition.dx.clamp(
    edgePadding,
    (screen.width - menuWidth - edgePadding).clamp(edgePadding, screen.width),
  );
  final double top = localPosition.dy.clamp(
    edgePadding,
    (screen.height - estimatedHeight - edgePadding).clamp(
      edgePadding,
      screen.height,
    ),
  );

  final bool animate =
      !Get.isRegistered<ThemeService>() ||
      Get.find<ThemeService>().animationsEnabled.value;
  final Duration menuDuration = animate
      ? const Duration(milliseconds: 120)
      : Duration.zero;

  late OverlayEntry overlayEntry;
  final GlobalKey<_ContextMenuOverlayState> overlayKey =
      GlobalKey<_ContextMenuOverlayState>();
  bool closed = false;

  void close() {
    if (closed) return;
    closed = true;

    final _ContextMenuOverlayState? host = overlayKey.currentState;
    if (host == null) {
      overlayEntry.remove();
    } else {
      host.close();
    }
  }

  overlayEntry = OverlayEntry(
    builder: (context) {
      return _ContextMenuOverlay(
        key: overlayKey,
        left: left,
        top: top,
        entries: entries,
        duration: menuDuration,
        onClosed: () {
          if (overlayEntry.mounted) overlayEntry.remove();
        },
        onAction: (action) {
          close();
          action.onSelected();
        },
      );
    },
  );

  overlay.insert(overlayEntry);

  return Future<void>.delayed(Duration.zero);
}

class _ContextMenuOverlay extends StatefulWidget {
  const _ContextMenuOverlay({
    super.key,
    required this.left,
    required this.top,
    required this.entries,
    required this.onAction,
    required this.onClosed,
    required this.duration,
  });

  final double left;
  final double top;
  final List<ContextMenuEntry> entries;
  final ValueChanged<ContextMenuAction> onAction;
  final VoidCallback onClosed;
  final Duration duration;

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const double _menuWidth = 248;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _closing = false;

  double _submenuOffset = 0;
  Widget Function(VoidCallback closeMenu)? _submenuBuilder;
  Timer? _submenuHideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _submenuHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void close() {
    if (_closing) return;
    _closing = true;
    _submenuHideTimer?.cancel();

    if (widget.duration == Duration.zero) {
      widget.onClosed();
      return;
    }

    _controller.reverse().whenComplete(widget.onClosed);
  }

  void _showSubmenu(double offset, Widget Function(VoidCallback) builder) {
    _submenuHideTimer?.cancel();
    if (_submenuBuilder == builder && _submenuOffset == offset) return;

    setState(() {
      _submenuOffset = offset;
      _submenuBuilder = builder;
    });
  }

  void _scheduleSubmenuHide() {
    _submenuHideTimer?.cancel();
    _submenuHideTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _submenuBuilder = null);
    });
  }

  void _onAction(ContextMenuAction action) {
    if (action.submenu != null) return;
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size screenSize = mq.size;
    const double flyoutWidth = 472;
    const double flyoutHeight = 320;
    const double edgePadding = 8;

    double flyoutLeft = widget.left + _menuWidth + 4;
    if (flyoutLeft + flyoutWidth + edgePadding > screenSize.width) {
      flyoutLeft = widget.left - flyoutWidth - 4;
    }
    flyoutLeft = flyoutLeft
        .clamp(edgePadding, screenSize.width - flyoutWidth - edgePadding)
        .clamp(0, screenSize.width);

    double flyoutTop = widget.top + _submenuOffset;
    if (flyoutTop + flyoutHeight + edgePadding > screenSize.height) {
      flyoutTop = screenSize.height - flyoutHeight - edgePadding;
    }
    flyoutTop = flyoutTop
        .clamp(edgePadding, screenSize.height - flyoutHeight - edgePadding)
        .clamp(0, screenSize.height);

    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final Widget Function(VoidCallback)? submenu = _submenuBuilder;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => close(),
            onSecondaryTapDown: (_) => close(),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                close();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                alignment: Alignment.topLeft,
                child: _ContextMenuPanel(
                  entries: widget.entries,
                  onAction: _onAction,
                  onSubmenuShow: _showSubmenu,
                  onSubmenuHide: _scheduleSubmenuHide,
                ),
              ),
            ),
          ),
        ),
        if (submenu != null)
          Positioned(
            left: flyoutLeft,
            top: flyoutTop,
            child: MouseRegion(
              onEnter: (_) => _submenuHideTimer?.cancel(),
              onExit: (_) => _scheduleSubmenuHide(),
              child: _SubmenuPanel(child: submenu(() => close())),
            ),
          ),
      ],
    );
  }
}

class _SubmenuPanel extends StatelessWidget {
  const _SubmenuPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.menu,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.menuBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _ContextMenuPanel extends StatelessWidget {
  const _ContextMenuPanel({
    required this.entries,
    required this.onAction,
    required this.onSubmenuShow,
    required this.onSubmenuHide,
  });

  final List<ContextMenuEntry> entries;
  final ValueChanged<ContextMenuAction> onAction;
  final void Function(double offset, Widget Function(VoidCallback) builder)
  onSubmenuShow;
  final VoidCallback onSubmenuHide;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    double offset = 6;

    for (final entry in entries) {
      if (entry case ContextMenuActionEntry(:final action)) {
        final double rowOffset = offset;
        children.add(
          _MenuRow(
            action: action,
            onTap: () => onAction(action),
            onHoverChanged: (hovered) {
              if (!hovered) {
                onSubmenuHide();
              } else if (action.submenu != null) {
                onSubmenuShow(rowOffset, action.submenu!);
              }
            },
          ),
        );
        offset += 30;
      } else {
        children.add(_MenuSeparator());
        offset += 9;
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 248,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.menu,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.menuBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(height: 1, color: context.colors.menuBorder),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.action,
    required this.onTap,
    required this.onHoverChanged,
  });

  final ContextMenuAction action;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final bool enabled = action.enabled;
    final bool hasSubmenu = action.submenu != null;

    final Color contentColor = !enabled
        ? context.colors.textFaint.withValues(alpha: 0.5)
        : action.danger
        ? context.colors.dangerBright
        : context.colors.menuLabel;

    return HoverRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onHoverChanged: onHoverChanged,
      builder: (context, hovered) {
        return GestureDetector(
          onTap: enabled && !hasSubmenu ? onTap : null,
          child: Container(
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: hovered && enabled
                  ? context.colors.surfaceHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 15,
                  color: !enabled
                      ? context.colors.textFaint.withValues(alpha: 0.5)
                      : action.danger
                      ? context.colors.dangerBright
                      : context.colors.menuIcon,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: contentColor),
                  ),
                ),
                if (hasSubmenu)
                  Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: enabled
                        ? context.colors.menuIcon
                        : context.colors.textFaint.withValues(alpha: 0.5),
                  )
                else if (action.shortcut != null)
                  Text(
                    action.shortcut!,
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? context.colors.menuShortcut
                          : context.colors.textFaint.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
