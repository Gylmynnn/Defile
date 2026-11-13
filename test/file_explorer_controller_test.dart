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

class _FakeFs extends FileSystemService {
  _FakeFs(this.entries);

  final List<rust.FileEntry> entries;

  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async => entries;
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
}
