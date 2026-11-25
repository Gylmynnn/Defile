import 'package:defile/src/features/file_explorer/services/window_controls_service.dart';
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:defile/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        'build/linux/x64/debug/bundle/lib/librust_lib_defile.so',
      ),
    );
  });

  tearDown(Get.reset);

  test('WindowControlsService restores and persists hidden controls', () async {
    const String minimizeKey = 'window-show-minimize';
    const String closeKey = 'window-show-close';

    // Keep the user's stored preferences and restore them afterwards.
    final String originalMinimize = await rust_system.getViewSetting(
      key: minimizeKey,
    );
    final String originalClose = await rust_system.getViewSetting(
      key: closeKey,
    );
    addTearDown(() async {
      await rust_system.setViewSetting(
        key: minimizeKey,
        value: originalMinimize,
      );
      await rust_system.setViewSetting(key: closeKey, value: originalClose);
    });

    await rust_system.setViewSetting(key: minimizeKey, value: '');
    await rust_system.setViewSetting(key: closeKey, value: '');

    // With no stored value both controls default to visible.
    final WindowControlsService service = Get.put(WindowControlsService());
    await service.init();
    expect(service.showMinimize.value, isTrue);
    expect(service.showClose.value, isTrue);

    service.setShowMinimize(false);
    service.setShowClose(false);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // A fresh instance reads the persisted flags, so hidden controls stay
    // hidden after a reload.
    final WindowControlsService reloaded = WindowControlsService();
    await reloaded.init();
    expect(reloaded.showMinimize.value, isFalse);
    expect(reloaded.showClose.value, isFalse);

    // Toggling back on is persisted too.
    reloaded.setShowMinimize(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      await rust_system.getViewSetting(key: minimizeKey),
      'true',
    );
    expect(await rust_system.getViewSetting(key: closeKey), 'false');
    reloaded.onClose();
  });
}