import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final FontWeight fontWeight;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (widget.danger) {
      bgColor = _pressed || _hovered ? colors.dangerBright : colors.danger;
      borderColor = colors.dangerBright;
      textColor = Colors.white;
    } else if (widget.primary) {
      bgColor = _pressed
          ? colors.selection
          : _hovered
          ? colors.selectionBorder
          : colors.selection;
      borderColor = colors.selectionBorder;
      textColor = colors.textPrimary;
    } else {
      bgColor = _pressed
          ? colors.rowHover
          : _hovered
          ? colors.elevatedHover
          : colors.elevated;
      borderColor = _hovered
          ? colors.elevatedBorderHover
          : colors.elevatedBorder;
      textColor = _hovered ? colors.textStrong : colors.textLabel;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: widget.fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
