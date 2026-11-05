part of 'file_explorer_controller.dart';

/// A parsed path-like search query such as `.config/nvim`.
///
/// [ancestors] lists the directory-name patterns the search must traverse
/// (in order), and [pattern] is what the resulting entries themselves must
/// match — an empty [pattern] (query ends with `/`) matches every direct
/// child. Only the LAST segment matches entry names; all earlier segments
/// must match ancestor directories on the way down.
class PathSearchPlan {
  const PathSearchPlan({required this.ancestors, required this.pattern});

  final List<String> ancestors;
  final String pattern;
}

extension ExplorerPathSearch on FileExplorerController {
  /// Turns a lowercased query into a [PathSearchPlan], or null when the query
  /// is not path-like (no usable `/`, e.g. `.config`) or this view is not a
  /// plain directory listing (recents/trash fall back to the plain filter).
  PathSearchPlan? planPathSearch(String query) {
    if (location.value != ExplorerLocation.directory) return null;

    final List<String> parts = query.split('/');
    if (parts.length < 2) return null;

    final List<String> ancestors = [
      for (final part in parts.take(parts.length - 1))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (ancestors.isEmpty) return null;

    return PathSearchPlan(ancestors: ancestors, pattern: parts.last.trim());
  }

  /// Debounced [updateSearch]-triggered path search. Only queries with a `/`
  /// are resolved asynchronously; anything else (plain filter or empty)
  /// simply drops stale results without leaving a pending timer behind.
  void schedulePathSearch() {
    final String query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty || !query.contains('/')) {
      resetPathSearch();
      return;
    }
    _pathSearchTimer?.cancel();
    _pathSearchTimer = Timer(
      FileExplorerController._pathSearchDebounce,
      _runPathSearch,
    );
  }

  /// Drops any in-flight/debounced path search and its results (the plain
  /// name filter takes over for queries without `/`).
  void resetPathSearch() {
    _pathSearchTimer?.cancel();
    final bool hadWork =
        _pathSearchTimer != null || _pathSearchResults != null;
    _pathSearchTimer = null;
    _pathSearchGeneration++;
    _pathSearchResults = null;
    if (hadWork) _pathSearchVersion.value++;
  }

  Future<void> _runPathSearch() async {
    final String query = searchQuery.value.trim().toLowerCase();
    final PathSearchPlan? plan = planPathSearch(query);
    if (plan == null) {
      resetPathSearch();
      return;
    }

    final int generation = ++_pathSearchGeneration;
    final List<rust.FileEntry>? results = await _collectPathMatches(
      plan,
      generation,
    );
    if (generation != _pathSearchGeneration) return;

    _pathSearchResults = results ?? const <rust.FileEntry>[];
    _pathSearchVersion.value++;
  }

  /// Walks the directory tree following [plan.ancestors] and returns the
  /// entries matching [plan.pattern] inside the deepest matched directories,
  /// or null when the search was superseded (newer query / navigation).
  Future<List<rust.FileEntry>?> _collectPathMatches(
    PathSearchPlan plan,
    int generation,
  ) async {
    final int baseRevision = _entriesRevision;
    final String basePath = currentPath.value;

    List<rust.FileEntry> level = entries;
    for (int depth = 0; depth < plan.ancestors.length; depth++) {
      final String pattern = plan.ancestors[depth];
      final List<rust.FileEntry> matched = <rust.FileEntry>[];

      for (final entry in level) {
        if (entry.isDirectory &&
            entry.name.toLowerCase().contains(pattern)) {
          matched.add(entry);
          if (matched.length >= FileExplorerController._pathSearchMaxExpand) break;
        }
      }
      if (matched.isEmpty) return const <rust.FileEntry>[];

      final List<List<rust.FileEntry>> childLists = await Future.wait([
        for (final dir in matched) _listChildren(dir.path),
      ]);
      if (generation != _pathSearchGeneration ||
          _entriesRevision != baseRevision ||
          currentPath.value != basePath) {
        return null;
      }

      if (depth == plan.ancestors.length - 1) {
        final List<rust.FileEntry> results = <rust.FileEntry>[];
        for (final children in childLists) {
          for (final entry in children) {
            if (plan.pattern.isEmpty ||
                entry.name.toLowerCase().contains(plan.pattern)) {
              results.add(entry);
              if (results.length >= FileExplorerController._pathSearchMaxResults) {
                return results;
              }
            }
          }
        }
        return List<rust.FileEntry>.unmodifiable(results);
      }

      level = [for (final children in childLists) ...children];
    }
    return const <rust.FileEntry>[];
  }

  /// Failing a listing (permissions, races) must not kill the whole search:
  /// such ancestors simply contribute no children.
  Future<List<rust.FileEntry>> _listChildren(String path) async {
    try {
      return await fileSystemService.listDirectory(path);
    } catch (_) {
      return const <rust.FileEntry>[];
    }
  }
}
