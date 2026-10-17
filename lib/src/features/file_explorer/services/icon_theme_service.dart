import 'dart:typed_data';

import 'package:defile/src/rust/api/icon_theme.dart' as rust;
import 'package:get/get.dart';

class IconThemeService extends GetxService {
  final RxString themeName = ''.obs;
  final RxList<rust.IconThemeEntry> themes = <rust.IconThemeEntry>[].obs;

  final Map<String, Future<Uint8List?>> _pending = {};
  final Map<String, Uint8List?> _resolved = {};

  Future<void> init() async {
    await refreshThemes();

    try {
      themeName.value = await rust.getIconTheme();
    } catch (_) {
      themeName.value = '';
    }
  }

  Future<void> refreshThemes() async {
    try {
      themes.assignAll(await rust.listIconThemes());
    } catch (_) {
      themes.clear();
    }
  }

  Future<void> setTheme(String name) async {
    themeName.value = name;
    _pending.clear();
    _resolved.clear();

    try {
      await rust.setIconTheme(name: name);
    } catch (_) {}
  }

  bool hasIconPng(List<String> iconNames, int pixelSize, {String? theme}) {
    final String? key = _key(iconNames, pixelSize, theme);
    return key != null && _resolved.containsKey(key);
  }

  Uint8List? cachedIconPng(
    List<String> iconNames,
    int pixelSize, {
    String? theme,
  }) {
    final String? key = _key(iconNames, pixelSize, theme);
    return key == null ? null : _resolved[key];
  }

  Future<Uint8List?> iconPng(
    List<String> iconNames,
    int pixelSize, {
    String? theme,
  }) {
    final String? key = _key(iconNames, pixelSize, theme);
    if (key == null) {
      return Future<Uint8List?>.value();
    }

    return _pending.putIfAbsent(key, () async {
      Uint8List? bytes;

      try {
        bytes = await rust.iconPng(
          theme: theme ?? themeName.value,
          iconNames: iconNames,
          size: pixelSize,
        );
      } catch (_) {
        bytes = null;
      }

      _resolved[key] = bytes;
      return bytes;
    });
  }

  String? _key(List<String> iconNames, int pixelSize, String? theme) {
    final String active = theme ?? themeName.value;
    if (active.isEmpty || iconNames.isEmpty) return null;

    return '$active|$pixelSize|${iconNames.join(',')}';
  }
}
