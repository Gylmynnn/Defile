import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';

class ContextMenuAction {
  ContextMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.shortcut,
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool danger;
  final bool enabled;
  final VoidCallback onSelected;
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

  late OverlayEntry overlayEntry;
  bool closed = false;

  void close() {
    if (closed) return;
    closed = true;
    overlayEntry.remove();
  }

  overlayEntry = OverlayEntry(
    builder: (context) {
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
            left: left,
            top: top,
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
              child: _ContextMenuPanel(
                entries: entries,
                onAction: (action) {
                  close();
                  action.onSelected();
                },
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(overlayEntry);

  return Future<void>.delayed(Duration.zero);
}

class _ContextMenuPanel extends StatelessWidget {
  const _ContextMenuPanel({required this.entries, required this.onAction});

  final List<ContextMenuEntry> entries;
  final ValueChanged<ContextMenuAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 248,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.menu,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.menuBorder),
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
          children: [
            for (final entry in entries)
              if (entry case ContextMenuActionEntry(:final action))
                _MenuRow(action: action, onTap: () => onAction(action))
              else
                _MenuSeparator(),
          ],
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
      child: Container(height: 1, color: AppColors.menuBorder),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.action, required this.onTap});

  final ContextMenuAction action;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final bool enabled = action.enabled;

    final Color contentColor = !enabled
        ? AppColors.textFaint.withValues(alpha: 0.5)
        : action.danger
        ? AppColors.dangerBright
        : AppColors.menuLabel;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: Container(
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? AppColors.surfaceHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                action.icon,
                size: 15,
                color: !enabled
                    ? AppColors.textFaint.withValues(alpha: 0.5)
                    : action.danger
                    ? AppColors.dangerBright
                    : AppColors.menuIcon,
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
              if (action.shortcut != null)
                Text(
                  action.shortcut!,
                  style: TextStyle(
                    fontSize: 11,
                    color: enabled
                        ? AppColors.menuShortcut
                        : AppColors.textFaint.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
