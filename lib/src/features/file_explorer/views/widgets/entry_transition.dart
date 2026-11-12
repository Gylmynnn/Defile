import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/theme_service.dart';

/// Hosts one short reveal animation for the directory contents.
///
/// The animation restarts whenever [transitionKey] changes, which happens when
/// another folder is opened. Items pick it up through [EntryReveal] and play a
/// staggered fade/slide, so a new listing settles in instead of popping.
class EntryTransitionScope extends StatefulWidget {
  const EntryTransitionScope({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  /// Identifies the current listing (usually the directory path). A different
  /// value starts the reveal again; refreshes of the same listing keep it.
  final String transitionKey;

  final Widget child;

  @override
  State<EntryTransitionScope> createState() => _EntryTransitionScopeState();
}

class _EntryTransitionScopeState extends State<EntryTransitionScope>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 220);

  // Starts settled so the first directory (app start) does not animate.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );

  bool get _enabled {
    if (!Get.isRegistered<ThemeService>()) return true;
    return Get.find<ThemeService>().animationsEnabled.value;
  }

  @override
  void didUpdateWidget(covariant EntryTransitionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey == widget.transitionKey) return;

    if (_enabled) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EntryTransition(
      animation: _controller,
      duration: _duration,
      enabled: _enabled,
      child: widget.child,
    );
  }
}

class _EntryTransition extends InheritedWidget {
  const _EntryTransition({
    required this.animation,
    required this.duration,
    required this.enabled,
    required super.child,
  });

  final Animation<double> animation;
  final Duration duration;
  final bool enabled;

  @override
  bool updateShouldNotify(_EntryTransition oldWidget) =>
      animation != oldWidget.animation ||
      duration != oldWidget.duration ||
      enabled != oldWidget.enabled;
}

/// Reveals a single entry as part of the listing transition.
///
/// Items are staggered by [index] for the first few rows only; the rest start
/// together so long directories stay snappy. When no transition is running the
/// child is returned untouched.
class EntryReveal extends StatelessWidget {
  const EntryReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const double _staggerMs = 14;
  static const double _maxStaggerMs = 112;
  static const double _slide = 10;

  @override
  Widget build(BuildContext context) {
    final _EntryTransition? transition = context
        .dependOnInheritedWidgetOfExactType<_EntryTransition>();

    if (transition == null || !transition.enabled) return child;

    final double totalMs = transition.duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return child;

    final double start =
        (index * _staggerMs).clamp(0.0, _maxStaggerMs).toDouble() / totalMs;

    return AnimatedBuilder(
      animation: transition.animation,
      child: child,
      builder: (context, child) {
        final double raw =
            ((transition.animation.value - start) / (1 - start))
                .clamp(0.0, 1.0)
                .toDouble();
        final double t = Curves.easeOutCubic.transform(raw);

        // A zero translation is painted without an extra layer, so leaving the
        // wrappers mounted once the animation settled costs nothing.
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, _slide * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
