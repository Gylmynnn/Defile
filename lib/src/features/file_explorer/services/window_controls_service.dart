import 'dart:async';

import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

/// Owns the custom window controls at the far right of the shared title bar:
/// minimize and close.
///
/// The visibility switches are persisted through the view-settings store so a
/// hidden button stays hidden after a reload.
class WindowControlsService extends GetxService {
  static const String _showMinimizeKey = 'window-show-minimize';
  static const String _showCloseKey = 'window-show-close';

  final RxBool showMinimize = true.obs;
  final RxBool showClose = true.obs;

  Future<void>? _loading;

  /// Loads the stored visibility flags. Cached so startup can both kick the
  /// load off from the binding and await the same future before the first
  /// frame (no flash of a control the user hid).
  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final String raw = await rust_system.getViewSetting(
        key: _showMinimizeKey,
      );
      if (raw.isNotEmpty) showMinimize.value = raw == 'true';
    } catch (_) {}

    try {
      final String raw = await rust_system.getViewSetting(key: _showCloseKey);
      if (raw.isNotEmpty) showClose.value = raw == 'true';
    } catch (_) {}
  }

  void setShowMinimize(bool value) {
    if (showMinimize.value == value) return;
    showMinimize.value = value;
    unawaited(_persist(_showMinimizeKey, value));
  }

  void setShowClose(bool value) {
    if (showClose.value == value) return;
    showClose.value = value;
    unawaited(_persist(_showCloseKey, value));
  }

  Future<void> _persist(String key, bool value) async {
    try {
      await rust_system.setViewSetting(key: key, value: '$value');
    } catch (_) {}
  }

  @override
  void onClose() {
    showMinimize.close();
    showClose.close();
    super.onClose();
  }

  Future<void> minimizeWindow() async {
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  Future<void> closeWindow() async {
    try {
      await windowManager.close();
    } catch (_) {}
  }
}
