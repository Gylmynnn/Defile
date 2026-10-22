import 'package:flutter/material.dart';

class HoverRegion extends StatefulWidget {
  const HoverRegion({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
    this.onHoverChanged,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;

    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(context, _hovered),
    );
  }
}
