import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

/// Owns the custom window controls at the far right of the shared title bar:
/// minimize and close.
///
/// The visibility switches intentionally live in memory, matching the other
/// window-level toggles (preview panel, animations, sidebar), so hiding a
/// button never touches the settings store.
class WindowControlsService extends GetxService {
  final RxBool showMinimize = true.obs;
  final RxBool showClose = true.obs;

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
