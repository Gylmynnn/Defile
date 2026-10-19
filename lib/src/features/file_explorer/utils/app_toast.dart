import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../services/theme_service.dart';

enum AppToastVariant { success, error, info }

OverlayEntry? _currentToast;

/// Compact notification anchored to the top-right corner, styled like the
/// context menu / popup shell. Replaces the full-width bottom snackbar.
void showAppToast({
  required String title,
  required String message,
  AppToastVariant? variant,
  Duration duration = const Duration(seconds: 3),
}) {
  final NavigatorState? navigator = Get.key.currentState;
  final OverlayState? overlay = navigator?.overlay;
  if (overlay == null) return;

  _currentToast?.remove();
  _currentToast = null;

  final bool animate =
      !Get.isRegistered<ThemeService>() ||
      Get.find<ThemeService>().animationsEnabled.value;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(
      title: title,
      message: message,
      variant: variant ?? _inferVariant(title),
      duration: duration,
      animate: animate,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_currentToast, entry)) _currentToast = null;
      },
    ),
  );

  _currentToast = entry;
  overlay.insert(entry);
}

AppToastVariant _inferVariant(String title) {
  final String lower = title.toLowerCase();
  if (lower.contains('fail') ||
      lower.contains('error') ||
      lower.contains('empty') ||
      lower.contains('partial')) {
    return AppToastVariant.error;
  }
  if (lower.contains('success') ||
      lower.contains('copied') ||
      lower.contains('cut') ||
      lower.contains('deleted') ||
      lower.contains('renamed') ||
      lower.contains('created') ||
      lower.contains('trash emptied')) {
    return AppToastVariant.success;
  }
  return AppToastVariant.info;
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.title,
    required this.message,
    required this.variant,
    required this.duration,
    required this.animate,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final AppToastVariant variant;
  final Duration duration;
  final bool animate;
  final VoidCallback onDismissed;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animate
        ? const Duration(milliseconds: 180)
        : Duration.zero,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.12, 0),
    end: Offset.zero,
  ).animate(_fade);
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (widget.variant) {
      AppToastVariant.success => (
        Icons.check_circle_outline,
        AppColors.success,
      ),
      AppToastVariant.error => (Icons.error_outline, AppColors.danger),
      AppToastVariant.info => (Icons.info_outline, AppColors.accent),
    };

    return Positioned(
      top: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                width: 320,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.menu,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.menuBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xA6000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
