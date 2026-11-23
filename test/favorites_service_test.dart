import 'dart:convert';

import 'package:defile/src/features/file_explorer/services/favorites_service.dart';
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

  test('FavoritesService pins, dedupes and persists directories', () async {
    // The service stores favorites in the shared view-settings store; keep
    // whatever the user had and restore it afterwards.
    final String originalRaw = await rust_system.getViewSetting(
      key: 'favorites',
    );
    addTearDown(
      () => rust_system.setViewSetting(key: 'favorites', value: originalRaw),
    );

    await rust_system.setViewSetting(key: 'favorites', value: '');

    final FavoritesService service = Get.put(FavoritesService());
    await service.init();
    expect(service.paths, isEmpty);

    // Trailing slashes normalize away and duplicates collapse.
    await service.addAll(<String>[
      '/tmp/defile-fav-a/',
      '/tmp/defile-fav-a',
      '/tmp/defile-fav-b',
    ]);
    expect(service.paths, <String>['/tmp/defile-fav-a', '/tmp/defile-fav-b']);
    expect(service.contains('/tmp/defile-fav-a/'), isTrue);

    // Toggle pins then unpins.
    expect(await service.toggle('/tmp/defile-fav-c'), isTrue);
    expect(service.contains('/tmp/defile-fav-c'), isTrue);
    expect(await service.toggle('/tmp/defile-fav-c'), isFalse);
    expect(service.contains('/tmp/defile-fav-c'), isFalse);

    // The list survives a restart: a fresh instance reads the same store.
    final FavoritesService reloaded = FavoritesService();
    await reloaded.init();
    expect(
      reloaded.paths,
      <String>['/tmp/defile-fav-a', '/tmp/defile-fav-b'],
    );

    // The store holds the paths as JSON.
    final String stored = await rust_system.getViewSetting(key: 'favorites');
    expect(jsonDecode(stored), <String>['/tmp/defile-fav-a', '/tmp/defile-fav-b']);
  });
}
