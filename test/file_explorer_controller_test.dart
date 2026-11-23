import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

rust.FileEntry _entry(
  String name, {
  BigInt? size,
  bool directory = false,
  int modified = 0,
}) => rust.FileEntry(
  name: name,
  path: '/$name',
  isDirectory: directory,
  isFile: !directory,
  sizeBytes: size ?? BigInt.zero,
  modifiedSeconds: modified,
);

/// Same, but with an explicit absolute path (needed by the path-keyed fake
/// filesystem below).
rust.FileEntry _entryAt(String name, String path, {bool directory = false}) =>
    rust.FileEntry(
      name: name,
      path: path,
      isDirectory: directory,
      isFile: !directory,
      sizeBytes: BigInt.zero,
      modifiedSeconds: 0,
    );

class _FakeFs extends FileSystemService {
  _FakeFs(this.entries);

  final List<rust.FileEntry> entries;

  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async => entries;
}

class _TreeFs extends FileSystemService {
  _TreeFs(this.tree);

  final Map<String, List<rust.FileEntry>> tree;

  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async =>
      tree[path] ?? const <rust.FileEntry>[];
}

/// Records every directory read so the caching behavior can be asserted.
class _CountingFs extends FileSystemService {
  _CountingFs(this.tree);

  final Map<String, List<rust.FileEntry>> tree;
  final List<String> calls = <String>[];

  int readsOf(String path) => calls.where((call) => call == path).length;

  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async {
    calls.add(path);
    return tree[path] ?? const <rust.FileEntry>[];
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets('visibleEntries memoizes then refreshes on change', (
    tester,
  ) async {
    final controller = Get.put(
      FileExplorerController(_FakeFs([_entry('alpha'), _entry('beta')])),
    );

    await tester.runAsync(() => controller.loadDirectory('/'));

    List<String> names() =>
        controller.visibleEntries.map((entry) => entry.name).toList();

    expect(names(), ['alpha', 'beta']);

    final List<rust.FileEntry> cached = controller.visibleEntries;
    expect(identical(controller.visibleEntries, cached), isTrue);

    controller.searchQuery.value = 'beta';
    expect(names(), ['beta']);
    final List<rust.FileEntry> searchCached = controller.visibleEntries;
    expect(identical(controller.visibleEntries, searchCached), isTrue);

    controller.searchQuery.value = '';
    expect(names(), ['alpha', 'beta']);

    controller.entries.assignAll([_entry('gamma')]);
    expect(names(), ['gamma']);

    controller.selection.assignAll(controller.entries);
    expect(controller.selectionSnapshot.single.name, 'gamma');

    controller.selection.clear();
    expect(controller.selectionSnapshot, isEmpty);
  });

  testWidgets('visibleEntries sorts by field and hides dotfiles', (
    tester,
  ) async {
    final controller = Get.put(
      FileExplorerController(
        _FakeFs([
          _entry('beta.txt', size: BigInt.from(10)),
          _entry('alpha.txt', size: BigInt.from(50)),
          _entry('.hidden', size: BigInt.from(5)),
          _entry('folder', directory: true),
        ]),
      ),
    );

    await tester.runAsync(() => controller.loadDirectory('/'));

    List<String> names() =>
        controller.visibleEntries.map((entry) => entry.name).toList();

    // Default: folder first, then name ascending, dotfiles visible.
    expect(names(), ['folder', '.hidden', 'alpha.txt', 'beta.txt']);

    controller.setSortField(ExplorerSortField.size);
    expect(names(), ['folder', '.hidden', 'beta.txt', 'alpha.txt']);

    controller.toggleHiddenFiles();
    expect(controller.showHidden.value, isFalse);
    expect(names(), ['folder', 'beta.txt', 'alpha.txt']);

    controller.setSortField(ExplorerSortField.name);
    controller.setSortAscending(false);
    expect(names(), ['folder', 'beta.txt', 'alpha.txt']);

    // Cached list is replaced once the sort key changes again.
    controller.setSortField(ExplorerSortField.modified);
    expect(names().first, 'folder');
  });

  test('canDropEntries rejects self, same parent, and nested destinations', () {
    final controller = FileExplorerController(_FakeFs(const []));
    final folder = rust.FileEntry(
      name: 'docs',
      path: '/home/docs',
      isDirectory: true,
      isFile: false,
      sizeBytes: BigInt.zero,
      modifiedSeconds: 0,
    );
    final file = rust.FileEntry(
      name: 'notes.txt',
      path: '/home/notes.txt',
      isDirectory: false,
      isFile: true,
      sizeBytes: BigInt.zero,
      modifiedSeconds: 0,
    );

    expect(controller.canDropEntries([file], '/home/target'), isTrue);
    expect(controller.canDropEntries([file], '/home'), isFalse);
    expect(controller.canDropEntries([folder], folder.path), isFalse);
    expect(controller.canDropEntries([folder], '/home/docs/sub'), isFalse);
    expect(controller.canDropEntries([], '/home/target'), isFalse);
  });

  testWidgets('columns load parent and preview listings', (tester) async {
    final controller = Get.put(
      FileExplorerController(
        _TreeFs({
          '/': [
            _entryAt('projects', '/projects', directory: true),
            _entryAt('readme.txt', '/readme.txt'),
          ],
          '/projects': [_entryAt('alpha', '/projects/alpha')],
        }),
      ),
    );

    controller.setViewMode(ExplorerViewMode.columns);
    await tester.runAsync(() => controller.loadDirectory('/'));
    await tester.pump();

    // Root has no parent listing.
    expect(controller.columnParentEntries, isEmpty);

    // Selecting the folder fills the preview column with its contents. The
    // preview refresh is debounced, so advance past the debounce window.
    controller.selectOnly(
      controller.entries.firstWhere((entry) => entry.name == 'projects'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(controller.columnPreviewPath.value, '/projects');
    expect(
      controller.columnPreviewEntries.map((entry) => entry.name).toList(),
      ['alpha'],
    );

    // Clearing the selection empties the preview again.
    controller.clearSelection();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(controller.columnPreviewEntries, isEmpty);
  });

  testWidgets('switching away from columns clears side listings', (
    tester,
  ) async {
    final controller = Get.put(
      FileExplorerController(_FakeFs([_entry('projects')])),
    );

    controller.setViewMode(ExplorerViewMode.columns);
    controller.selection.assignAll([_entryAt('projects', '/projects')]);
    controller.columnPreviewEntries.add(_entryAt('alpha', '/projects/alpha'));
    controller.columnParentEntries.add(_entryAt('home', '/home'));

    controller.setViewMode(ExplorerViewMode.list);

    expect(controller.columnPreviewEntries, isEmpty);
    expect(controller.columnParentEntries, isEmpty);
    expect(controller.columnPreviewPath.value, isEmpty);
  });

  testWidgets('sibling navigation does not re-read the parent listing', (
    tester,
  ) async {
    final fs = _CountingFs({
      '/': [
        _entryAt('a', '/a', directory: true),
        _entryAt('b', '/b', directory: true),
      ],
      '/a': [_entryAt('a1', '/a/a1')],
      '/b': [_entryAt('b1', '/b/b1')],
    });
    final controller = Get.put(
      FileExplorerController(fs, initialPath: '/a'),
    );
    controller.setViewMode(ExplorerViewMode.columns);

    // Let the controller bootstrap itself into /a.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(controller.currentPath.value, '/a');
    // Parent column listed once and shows both siblings.
    expect(fs.readsOf('/'), 1);
    expect(
      controller.columnParentEntries.map((entry) => entry.name).toList(),
      ['a', 'b'],
    );

    // Switching to the sibling folder keeps the same parent: no extra read,
    // and the parent entries object is left untouched.
    await tester.runAsync(() async {
      await controller.navigateTo('/b');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    expect(fs.readsOf('/'), 1);
    expect(fs.readsOf('/b'), 1);
    expect(
      controller.columnParentEntries.map((entry) => entry.name).toList(),
      ['a', 'b'],
    );
  });

  testWidgets('re-selecting a folder reuses the preview cache', (tester) async {
    final fs = _CountingFs({
      '/': [
        _entryAt('a', '/a', directory: true),
        _entryAt('b', '/b', directory: true),
      ],
      '/a': [_entryAt('a1', '/a/a1')],
      '/b': [_entryAt('b1', '/b/b1')],
    });
    final controller = Get.put(FileExplorerController(fs));
    controller.setViewMode(ExplorerViewMode.columns);

    await tester.runAsync(() => controller.loadDirectory('/'));
    await tester.pump();

    final rust.FileEntry a = controller.entries.firstWhere(
      (entry) => entry.name == 'a',
    );
    final rust.FileEntry b = controller.entries.firstWhere(
      (entry) => entry.name == 'b',
    );

    Future<void> settlePreview() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }

    controller.selectOnly(a);
    await settlePreview();
    expect(fs.readsOf('/a'), 1);
    expect(
      controller.columnPreviewEntries.map((entry) => entry.name).toList(),
      ['a1'],
    );

    controller.selectOnly(b);
    await settlePreview();
    expect(fs.readsOf('/b'), 1);
    expect(fs.readsOf('/a'), 1);

    // Going back to the first folder is served from the cache.
    controller.selectOnly(a);
    await settlePreview();
    expect(fs.readsOf('/a'), 1);
    expect(
      controller.columnPreviewEntries.map((entry) => entry.name).toList(),
      ['a1'],
    );
  });

  testWidgets('descending reuses the seeded parent listing', (tester) async {
    final fs = _CountingFs({
      '/': [_entryAt('a', '/a', directory: true)],
      '/a': [_entryAt('b', '/a/b', directory: true)],
      '/a/b': [_entryAt('c', '/a/b/c')],
    });
    final controller = Get.put(FileExplorerController(fs, initialPath: '/'));
    controller.setViewMode(ExplorerViewMode.columns);

    // Let the controller bootstrap itself into '/'.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(controller.currentPath.value, '/');
    expect(fs.readsOf('/'), 1);

    // Descend into /a: its listing is read once, and the parent column
    // resolves from the listing seeded when '/' was loaded.
    await tester.runAsync(() async {
      await controller.navigateTo('/a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    expect(fs.readsOf('/a'), 1);
    expect(fs.readsOf('/'), 1);
    expect(
      controller.columnParentEntries.map((entry) => entry.name).toList(),
      ['a'],
    );

    // Descend once more: '/a' was seeded, so it is not read again either.
    await tester.runAsync(() async {
      await controller.navigateTo('/a/b');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    expect(fs.readsOf('/a/b'), 1);
    expect(fs.readsOf('/a'), 1);
    expect(
      controller.columnParentEntries.map((entry) => entry.name).toList(),
      ['b'],
    );
  });

  testWidgets('selecting a file previews it in the columns pane', (
    tester,
  ) async {
    final controller = Get.put(
      FileExplorerController(
        _TreeFs({
          '/': [_entryAt('pic.png', '/pic.png')],
        }),
        initialPath: '/',
      ),
    );
    controller.setViewMode(ExplorerViewMode.columns);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    controller.selectOnly(controller.entries.single);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // The pane shows the file itself rather than a folder listing.
    expect(controller.columnPreviewPath.value, '/pic.png');
    expect(controller.columnPreviewFile.value?.path, '/pic.png');
    expect(controller.columnPreviewEntries, isEmpty);

    // Going back to a folder clears the file preview.
    controller.selectOnly(_entryAt('projects', '/projects', directory: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(controller.columnPreviewFile.value, isNull);
  });
}
