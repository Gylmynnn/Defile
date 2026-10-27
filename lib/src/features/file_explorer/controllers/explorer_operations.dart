part of 'file_explorer_controller.dart';

extension ExplorerOperations on FileExplorerController {
  rust.FileEntry? get primarySelection =>
      selection.isEmpty ? null : selection.last;

  bool get hasClipboard => clipboardEntries.isNotEmpty;

  String get trashPath {
    for (final place in places) {
      if (place.kind == rust_system.PlaceKind.trash) {
        return place.path;
      }
    }

    return '';
  }

  String get trashRootPath {
    final String path = trashPath;
    if (path.isEmpty) return '';

    return p.basename(path) == 'files' ? p.dirname(path) : path;
  }

  bool isInTrash(String path) {
    final String root = trashRootPath;
    if (root.isEmpty) return false;

    return path == root || p.isWithin(root, path);
  }

  bool get isCurrentInTrash => isInTrash(currentPath.value);

  void _removeFromClipboard(String path) {
    if (!clipboardEntries.any((item) => item.path == path)) return;

    clipboardEntries.assignAll(
      clipboardEntries.where((item) => item.path != path),
    );
  }

  void copyToClipboard(List<rust.FileEntry> entries) {
    if (entries.isEmpty) return;

    clipboardEntries.assignAll(entries);
    clipboardIsCut.value = false;

    showAppToast(
      title: 'Copied',
      message: entries.length == 1
          ? '"${entries.first.name}" is ready to be copied to another folder.'
          : '${entries.length} items ready to be copied to another folder.',
      variant: AppToastVariant.success,
    );
  }

  void cutToClipboard(List<rust.FileEntry> entries) {
    if (entries.isEmpty) return;

    clipboardEntries.assignAll(entries);
    clipboardIsCut.value = true;

    showAppToast(
      title: 'Cut',
      message: entries.length == 1
          ? '"${entries.first.name}" is ready to be moved to another folder.'
          : '${entries.length} items ready to be moved to another folder.',
      variant: AppToastVariant.success,
    );
  }

  Future<void> pasteIntoCurrentDirectory() async {
    final List<rust.FileEntry> items = List<rust.FileEntry>.of(
      clipboardEntries,
    );
    if (items.isEmpty) return;

    final bool cut = clipboardIsCut.value;
    if (cut) clipboardEntries.clear();

    await _transferEntries(
      entries: items,
      destinationDirectory: currentPath.value,
      move: cut,
    );
  }

  Future<void> _transferEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
    required bool move,
    String? newName,
  }) async {
    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        if (move) {
          await fileSystemService.moveEntry(
            sourcePath: entry.path,
            destinationDirectory: destinationDirectory,
            newName: newName ?? entry.name,
          );
        } else {
          await fileSystemService.copyEntry(
            sourcePath: entry.path,
            destinationDirectory: destinationDirectory,
            newName: newName ?? entry.name,
          );
        }

        succeeded++;
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    final String label = move ? 'moved' : 'copied';

    if (succeeded == entries.length) {
      showAppToast(
        title: 'Success',
        message: '${entries.length} item(s) $label.',
        variant: AppToastVariant.success,
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(
        title: 'Failed',
        message: lastError,
        variant: AppToastVariant.error,
      );
    } else {
      showAppToast(
        title: 'Partially completed',
        message: '$succeeded of ${entries.length} items $label.',
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> trashEntries(List<rust.FileEntry> entries) async {
    if (entries.isEmpty) return;

    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        await fileSystemService.moveToTrash(entry.path);
        succeeded++;
        _removeFromClipboard(entry.path);
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    if (succeeded == entries.length) {
      showAppToast(
        title: 'Trash',
        message: '${entries.length} item(s) moved to Trash.',
        variant: AppToastVariant.success,
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(
        title: 'Failed to move to Trash',
        message: lastError,
        variant: AppToastVariant.error,
      );
    } else {
      showAppToast(
        title: 'Partially failed',
        message: '$succeeded of ${entries.length} items moved to Trash.',
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> trashEntry(rust.FileEntry entry) => trashEntries([entry]);

  Future<void> deletePermanently(List<rust.FileEntry> entries) async {
    if (entries.isEmpty) return;

    int succeeded = 0;
    String? lastError;

    for (final entry in entries) {
      try {
        if (isInTrash(entry.path)) {
          await fileSystemService.deleteFromTrash(entry.path);
        } else {
          await fileSystemService.deleteEntryRecursive(entry.path);
        }

        succeeded++;
        _removeFromClipboard(entry.path);
      } catch (error) {
        lastError = error.toString();
      }
    }

    await refreshDirectory();

    if (succeeded == entries.length) {
      showAppToast(
        title: 'Deleted',
        message: '${entries.length} item(s) permanently deleted.',
        variant: AppToastVariant.success,
      );
    } else if (entries.length == 1 && lastError != null) {
      showAppToast(
        title: 'Failed to delete',
        message: lastError,
        variant: AppToastVariant.error,
      );
    } else {
      showAppToast(
        title: 'Partially failed',
        message: '$succeeded of ${entries.length} items deleted.',
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> emptyTrash() async {
    try {
      final int removed = await fileSystemService.emptyTrash();
      await refreshDirectory();

      showAppToast(
        title: 'Trash emptied',
        message: '$removed item(s) permanently deleted.',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Failed to empty Trash',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  static const List<String> _archiveSuffixes = [
    '.zip',
    '.tar',
    '.tar.gz',
    '.tgz',
  ];

  /// Whether the entry is an archive the built-in extractor understands.
  bool isExtractableArchive(rust.FileEntry entry) {
    if (entry.isDirectory) return false;

    final String lower = entry.name.toLowerCase();
    return _archiveSuffixes.any(lower.endsWith);
  }

  /// Name given to the folder an archive's contents land in.
  static String? _archiveRootName(String fileName) {
    final String lower = fileName.toLowerCase();

    for (final suffix in _archiveSuffixes) {
      if (lower.endsWith(suffix)) {
        return fileName.substring(0, fileName.length - suffix.length);
      }
    }

    return null;
  }

  /// Bundles [entries] into an archive named `<archiveFile>` in the current
  /// directory, de-duplicating the name when it already exists. [format]
  /// selects the output type: `zip` (default), `tar`, or `tar.gz`.
  Future<void> compressEntries(
    List<rust.FileEntry> entries, {
    required String archiveName,
    String format = 'zip',
  }) async {
    if (entries.isEmpty) return;

    final String trimmed = archiveName.trim();
    if (trimmed.isEmpty) {
      showAppToast(
        title: 'Empty archive name',
        message: 'Enter an archive name first',
        variant: AppToastVariant.error,
      );
      return;
    }

    final String extension = switch (format) {
      'tar' => '.tar',
      'tar.gz' => '.tar.gz',
      _ => '.zip',
    };
    final String fileName = trimmed.toLowerCase().endsWith(extension)
        ? trimmed
        : '$trimmed$extension';
    final String destination = _uniqueChildPath(currentPath.value, fileName);

    showAppToast(
      title: 'Compressing',
      message: 'Packing ${entries.length} item(s) into "${p.basename(destination)}"',
      variant: AppToastVariant.loading,
    );

    try {
      await fileSystemService.compressEntries(
        paths: entries.map((entry) => entry.path).toList(),
        destination: destination,
      );
      await refreshDirectory();

      showAppToast(
        title: 'Compressed',
        message: '${entries.length} item(s) packed into "${p.basename(destination)}"',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Failed to compress',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  /// Extracts an archive next to itself, into a folder named after it.
  Future<void> extractEntry(rust.FileEntry entry) async {
    final String? rootName = _archiveRootName(entry.name);
    if (rootName == null || rootName.trim().isEmpty) {
      showAppToast(
        title: 'Extract',
        message: 'Unsupported archive format. Zip, tar and tar.gz are supported.',
        variant: AppToastVariant.error,
      );
      return;
    }

    final String destination = _uniqueChildPath(
      p.dirname(entry.path),
      rootName,
    );

    showAppToast(
      title: 'Extracting',
      message: 'Unpacking "${entry.name}" into "${p.basename(destination)}"',
      variant: AppToastVariant.loading,
    );

    try {
      final BigInt items = await fileSystemService.extractArchive(
        path: entry.path,
        destinationDir: destination,
      );
      await refreshDirectory();

      showAppToast(
        title: 'Extracted',
        message:
            '$items item(s) extracted into "${p.basename(destination)}"',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Failed to extract',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
      return;
    }
  }

  /// Returns a child path in [directory] that does not exist yet by appending
  /// " (n)" before the extension.
  String _uniqueChildPath(String directory, String fileName) {
    String candidate = p.join(directory, fileName);
    if (!_pathExists(candidate)) return candidate;

    final String basename = p.basenameWithoutExtension(fileName);
    final String extension = p.extension(fileName);

    int counter = 2;
    while (_pathExists(candidate)) {
      candidate = p.join(directory, '$basename ($counter)$extension');
      counter++;
    }

    return candidate;
  }

  bool _pathExists(String path) =>
      io.FileSystemEntity.typeSync(path) != io.FileSystemEntityType.notFound;

  Future<void> _loadTerminalSettings() async {
    try {
      availableTerminals.assignAll(await rust_system.listTerminals());
    } catch (_) {}

    try {
      final String saved = await rust_system.getTerminal();
      if (saved.isNotEmpty && !availableTerminals.contains(saved)) {
        availableTerminals.add(saved);
      }
      terminal.value = saved;
    } catch (_) {}
  }

  Future<void> setTerminal(String value) async {
    terminal.value = value;

    try {
      await rust_system.setTerminal(terminal: value);
    } catch (error) {
      showAppToast(
        title: 'Terminal',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> openTerminalAt(String path) async {
    try {
      await rust_system.openInTerminal(path: path, terminal: terminal.value);
    } catch (error) {
      showAppToast(
        title: 'Terminal',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> openTerminal() => openTerminalAt(currentPath.value);

  Future<void> copyEntry({
    required rust.FileEntry entry,
    required String destinationDirectory,
    String? newName,
  }) {
    return _transferEntries(
      entries: [entry],
      destinationDirectory: destinationDirectory,
      move: false,
      newName: newName,
    );
  }

  Future<void> copyEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
  }) {
    return _transferEntries(
      entries: entries,
      destinationDirectory: destinationDirectory,
      move: false,
    );
  }

  Future<void> moveEntry({
    required rust.FileEntry entry,
    required String destinationDirectory,
    String? newName,
  }) {
    return _transferEntries(
      entries: [entry],
      destinationDirectory: destinationDirectory,
      move: true,
      newName: newName,
    );
  }

  Future<void> moveEntries({
    required List<rust.FileEntry> entries,
    required String destinationDirectory,
  }) {
    return _transferEntries(
      entries: entries,
      destinationDirectory: destinationDirectory,
      move: true,
    );
  }

  bool canDropEntries(
    List<rust.FileEntry> entries,
    String destinationDirectory,
  ) {
    if (entries.isEmpty || destinationDirectory.isEmpty) return false;

    final String destination = p.normalize(destinationDirectory);

    for (final entry in entries) {
      final String source = p.normalize(entry.path);

      if (source == destination) return false;
      if (p.dirname(source) == destination) return false;
      if (entry.isDirectory && p.isWithin(source, destination)) return false;
    }

    return true;
  }

  Future<void> renameEntry(rust.FileEntry entry, String newName) async {
    final String trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      showAppToast(
        title: 'Empty name',
        message: 'Enter a new name first.',
        variant: AppToastVariant.error,
      );
      return;
    }

    try {
      await fileSystemService.renameEntry(entry.path, trimmedName);
      await refreshDirectory();

      showAppToast(
        title: 'Success',
        message: '"${entry.name}" was renamed.',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Rename failed',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> createDirectory(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      showAppToast(
        title: 'Empty folder name',
        message: 'Enter a folder name first',
        variant: AppToastVariant.error,
      );
      return;
    }

    try {
      await fileSystemService.createDirectory(currentPath.value, trimmedName);
      await refreshDirectory();

      showAppToast(
        title: 'Success',
        message: 'Folder "$trimmedName" created',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Failed to create folder',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> openDirectory(rust.FileEntry entry) async {
    if (!entry.isDirectory) return;
    await navigateTo(entry.path);
  }

  Future<void> openFile(rust.FileEntry entry) async {
    if (entry.isDirectory) {
      await openDirectory(entry);
      return;
    }

    try {
      await fileSystemService.openFile(entry.path);
    } catch (error) {
      showAppToast(
        title: 'Failed to open file',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }

  Future<List<rust_system.OpenWithApp>> listOpenWithApps(String path) {
    return fileSystemService.listOpenWithApps(path);
  }

  Future<void> openWith(
    rust.FileEntry entry,
    rust_system.OpenWithApp app,
  ) async {
    try {
      await fileSystemService.openWith(entry.path, app.id);
    } catch (error) {
      showAppToast(
        title: 'Failed to open file',
        message: error.toString(),
        variant: AppToastVariant.error,
      );
    }
  }
}
