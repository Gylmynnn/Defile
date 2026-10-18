import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/theme_service.dart';

/// Opens a popup with a smooth fade + scale transition, honoring the
/// "Smooth animations" preference (instant when disabled).
Future<T?> showAppDialog<T>({
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final bool animate =
      !Get.isRegistered<ThemeService>() ||
      Get.find<ThemeService>().animationsEnabled.value;

  return Get.generalDialog<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: animate
        ? const Duration(milliseconds: 180)
        : Duration.zero,
    transitionBuilder: animate
        ? (context, animation, secondaryAnimation, child) {
            final CurvedAnimation curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            );
          }
        : null,
  );
}
