import 'package:defile/src/rust/api/file_entry.dart' as rust;

class FileSystemService {
  Future<List<rust.FileEntry>> listDirectory(String path) {
    return rust.listDirectory(path: path);
  }

  Future<void> openFile(String path) {
    return rust.openFile(path: path);
  }
}
