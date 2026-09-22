import 'package:defile/src/rust/api/file_entry.dart' as rust;

class FileSystemService {
  Future<List<rust.FileEntry>> listDirectory(String path) {
    return rust.listDirectory(path: path);
  }

  Future<void> openFile(String path) {
    return rust.openFile(path: path);
  }

  Future<String> createDirectory(String parentPath, String directoryName) {
    return rust.createDirectory(
      parentPath: parentPath,
      directoryName: directoryName,
    );
  }

  Future<String> renameEntry(String sourcePath, String newName) {
    return rust.renameEntry(sourcePath: sourcePath, newName: newName);
  }
}
