import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

rust.FileEntry _entry(String name) => rust.FileEntry(
  name: name,
  path: '/$name',
  isDirectory: false,
  isFile: true,
  sizeBytes: BigInt.zero,
  modifiedSeconds: 0,
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

    controller.searchQuery.value = '';
    expect(names(), ['alpha', 'beta']);

    controller.entries.assignAll([_entry('gamma')]);
    expect(names(), ['gamma']);
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
