part of 'file_explorer_page.dart';

class _LoadingShroud extends StatefulWidget {
  const _LoadingShroud({required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  State<_LoadingShroud> createState() => _LoadingShroudState();
}

class _LoadingShroudState extends State<_LoadingShroud> {
  static const Duration _delay = Duration(milliseconds: 150);

  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _LoadingShroud oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.loading && !oldWidget.loading) {
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _timer?.cancel();
      _timer = null;
      _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _visible = false;
    _timer?.cancel();
    _timer = Timer(_delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.loading && _visible)
          Positioned.fill(
            child: ColoredBox(
              color: context.colors.window.withValues(alpha: 0.55),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionBandPainter extends CustomPainter {
  _SelectionBandPainter(this.rect, this.colors) : super(repaint: rect);

  final ValueListenable<Rect?> rect;
  final AppThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? band = rect.value;
    if (band == null) return;

    final RRect rrect = RRect.fromRectAndRadius(band, const Radius.circular(3));

    canvas.drawRRect(
      rrect,
      Paint()..color = colors.selectionBorder.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.selectionBorder.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionBandPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.colors != colors;
}
