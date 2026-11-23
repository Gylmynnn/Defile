import 'dart:convert';

import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// App-wide list of pinned directories shown at the top of the sidebar.
///
/// Stored through the existing view-settings store (one file per key under
/// `~/.config/defile`), so no extra Rust API is needed. The list is shared by
/// every tab and survives restarts.
class FavoritesService extends GetxService {
  static const String _settingKey = 'favorites';

  final RxList<String> paths = <String>[].obs;

  @override
  void onClose() {
    paths.close();
    super.onClose();
  }

  Future<void> init() async {
    try {
      final String raw = await rust_system.getViewSetting(key: _settingKey);
      if (raw.isEmpty) return;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final Set<String> loaded = <String>{};
      for (final value in decoded.whereType<String>()) {
        final String path = _normalize(value);
        if (path.isNotEmpty) loaded.add(path);
      }

      paths.assignAll(loaded);
    } catch (_) {
      // Corrupt or unavailable store: start with an empty list.
    }
  }

  bool contains(String path) => paths.contains(_normalize(path));

  Future<void> add(String path) async {
    final String normalized = _normalize(path);
    if (normalized.isEmpty || paths.contains(normalized)) return;

    paths.add(normalized);
    await _persist();
  }

  /// Adds every path that is not pinned yet and persists once. Returns the
  /// paths that were actually added.
  Future<List<String>> addAll(Iterable<String> values) async {
    final List<String> added = <String>[];

    for (final value in values) {
      final String path = _normalize(value);
      if (path.isEmpty || paths.contains(path)) continue;
      paths.add(path);
      added.add(path);
    }

    if (added.isNotEmpty) await _persist();
    return added;
  }

  Future<void> remove(String path) async {
    if (!paths.remove(_normalize(path))) return;
    await _persist();
  }

  /// Pins the path when missing, unpins it otherwise. Returns the new state.
  Future<bool> toggle(String path) async {
    if (contains(path)) {
      await remove(path);
      return false;
    }

    await add(path);
    return true;
  }

  Future<void> _persist() async {
    try {
      await rust_system.setViewSetting(
        key: _settingKey,
        value: paths.isEmpty ? '' : jsonEncode(paths.toList()),
      );
    } catch (_) {
      // Keep the in-memory list even when the settings file is unavailable.
    }
  }

  String _normalize(String path) {
    final String trimmed = path.trim();
    if (trimmed.isEmpty) return '';

    String normalized = p.normalize(trimmed);
    final String separator = p.separator;
    while (normalized.length > 1 && normalized.endsWith(separator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
