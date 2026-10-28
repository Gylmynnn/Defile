part of 'file_explorer_page.dart';

extension _ExplorerPageActions on _EntryContentState {
  void _showEntryMenu(
    BuildContext context,
    rust.FileEntry entry,
    Offset position,
  ) {
    final List<rust.FileEntry> targets = controller.selection.isEmpty
        ? <rust.FileEntry>[entry]
        : controller.selection.toList();
    final bool single = targets.length == 1;
    final bool inTrash = controller.isCurrentInTrash;

    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.open_in_new,
            label: single ? 'Open' : 'Open ${targets.length} Items',
            shortcut: 'Enter',
            onSelected: () async {
              for (final item in targets) {
                await controller.openFile(item);
              }
            },
          ),
        ),
        if (single && entry.isDirectory)
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.terminal,
              label: 'Open in Terminal',
              enabled: !inTrash,
              onSelected: () => controller.openTerminalAt(entry.path),
            ),
          ),
        if (single && entry.isDirectory)
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.tab,
              label: 'Open in New Tab',
              onSelected: () =>
                  Get.find<ExplorerTabsController>().addTab(path: entry.path),
            ),
          ),
        if (single && entry.isDirectory && !inTrash)
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.splitscreen,
              label: (Get.isRegistered<ExplorerTabsController>() &&
                      Get.find<ExplorerTabsController>().isSplit)
                  ? 'Open in Other Pane'
                  : 'Open in Split View',
              onSelected: () {
                if (Get.isRegistered<ExplorerTabsController>()) {
                  Get.find<ExplorerTabsController>()
                      .openInOtherPane(entry.path);
                }
              },
            ),
          ),
        if (single && entry.isFile && !inTrash)
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.apps_outlined,
              label: 'Open with...',
              onSelected: () {},
              submenu: (closeMenu) => OpenWithSubmenu(
                entry: entry,
                controller: controller,
                onDismiss: closeMenu,
              ),
            ),
          ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.content_cut,
            label: 'Cut',
            shortcut: 'Ctrl+X',
            enabled: !inTrash,
            onSelected: () => controller.cutToClipboard(targets),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.content_copy,
            label: 'Copy',
            shortcut: 'Ctrl+C',
            onSelected: () => controller.copyToClipboard(targets),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.assignment_outlined,
            label: 'Copy Path',
            onSelected: () => _copyPath(targets),
          ),
        ),
        if (!inTrash) ...[
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.folder_zip_outlined,
              label: single
                  ? 'Compress...'
                  : 'Compress ${targets.length} Items...',
              onSelected: () => _showCompressDialog(context, targets),
            ),
          ),
          if (single && controller.isExtractableArchive(entry))
            ContextMenuActionEntry(
              ContextMenuAction(
                icon: Icons.unarchive_outlined,
                label: 'Extract Here',
                onSelected: () => controller.extractEntry(entry),
              ),
            ),
        ],
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.drive_file_move_outlined,
            label: 'Move to...',
            enabled: !inTrash,
            onSelected: () => _pickDestination(targets, move: true),
          ),
        ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename...',
            shortcut: 'F2',
            enabled: single && !inTrash,
            onSelected: () => _showRenameDialog(context, entry),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: inTrash
                ? Icons.delete_forever_outlined
                : Icons.delete_outline,
            label: inTrash
                ? single
                      ? 'Delete Permanently'
                      : 'Delete ${targets.length} Items Permanently'
                : single
                ? 'Move to Trash'
                : 'Move ${targets.length} Items to Trash',
            shortcut: 'Delete',
            danger: true,
            onSelected: () => _removeSelection(),
          ),
        ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.info_outline,
            label: 'Properties',
            enabled: single,
            onSelected: () => _showPropertiesDialog(entry),
          ),
        ),
      ],
    );
  }

  void _showBackgroundMenu(BuildContext context, Offset position) {
    controller.clearSelection();

    final bool inTrash = controller.isCurrentInTrash;
    final bool inDirectory =
        controller.location.value == ExplorerLocation.directory;

    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.content_paste,
            label: 'Paste',
            shortcut: 'Ctrl+V',
            enabled: controller.hasClipboard && inDirectory && !inTrash,
            onSelected: controller.pasteIntoCurrentDirectory,
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.create_new_folder_outlined,
            label: 'New Folder',
            shortcut: 'Ctrl+Shift+N',
            enabled: inDirectory && !inTrash,
            onSelected: () => _showCreateFolderDialog(context),
          ),
        ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.refresh,
            label: 'Refresh',
            shortcut: 'Ctrl+R',
            onSelected: controller.refreshDirectory,
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.terminal,
            label: 'Open in Terminal',
            enabled: inDirectory && !inTrash,
            onSelected: controller.openTerminal,
          ),
        ),
        if (inTrash) ...[
          ContextMenuSeparator(),
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: Icons.delete_sweep_outlined,
              label: 'Empty Trash',
              danger: true,
              onSelected: () => _emptyTrash(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _emptyTrash() async {
    final bool confirmed = await _confirm(
      title: 'Empty Trash?',
      message: 'All items in Trash will be permanently deleted. This action cannot be undone.',
      confirmLabel: 'Empty',
    );

    if (!confirmed) return;

    await controller.emptyTrash();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showAppDialog<bool>(
      builder: (_) => AppDialog(
        title: title,
        width: 380,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
        actions: [
          AppDialogButton(
            label: 'Cancel',
            onTap: () => Get.back(result: false),
          ),
          AppDialogButton(
            label: confirmLabel,
            danger: true,
            onTap: () => Get.back(result: true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _copyPath(List<rust.FileEntry> entries) async {
    final String value = entries.map((entry) => entry.path).join('\n');
    await Clipboard.setData(ClipboardData(text: value));

    showAppToast(
      title: 'Path copied',
      message: entries.length == 1
          ? entries.first.path
          : '${entries.length} paths copied.',
      variant: AppToastVariant.success,
    );
  }

  Future<void> _pickDestination(
    List<rust.FileEntry> entries, {
    required bool move,
  }) async {
    final String? destination = await showAppDialog<String>(
      builder: (_) =>
          DirectoryPickerDialog(initialPath: controller.currentPath.value),
    );

    if (destination == null) return;

    if (move) {
      await controller.moveEntries(
        entries: entries,
        destinationDirectory: destination,
      );
    } else {
      await controller.copyEntries(
        entries: entries,
        destinationDirectory: destination,
      );
    }
  }

  void _showPropertiesDialog(rust.FileEntry entry) {
    showAppDialog(builder: (_) => PropertiesDialog(entry: entry));
  }

  void _showRenameDialog(BuildContext context, rust.FileEntry entry) {
    final TextEditingController textController = TextEditingController(
      text: entry.name,
    );

    showAppDialog(
      builder: (_) => AppDialog(
        title: 'Rename',
        width: 360,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New name'),
            onSubmitted: (value) {
              Get.back();
              controller.renameEntry(entry, value);
            },
          ),
        ),
        actions: [
          AppDialogButton(label: 'Cancel', onTap: Get.back),
          AppDialogButton(
            label: 'Save',
            primary: true,
            onTap: () {
              final String newName = textController.text;
              Get.back();
              controller.renameEntry(entry, newName);
            },
          ),
        ],
      ),
    );
  }

  void _showCompressDialog(BuildContext context, List<rust.FileEntry> targets) {
    final String defaultName = targets.length == 1
        ? _defaultArchiveName(targets.first.name)
        : 'archive';

    final TextEditingController textController = TextEditingController(
      text: defaultName,
    );

    String format = 'zip';

    showAppDialog(
      builder: (_) => AppDialog(
        title: 'Compress',
        width: 360,
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Archive name',
                      hintText: 'Example: Documents',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Format',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: context.colors.textFaint,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.colors.window,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        for (final entry in _archiveFormats.entries)
                          Expanded(
                            child: _ArchiveFormatSegment(
                              label: entry.key,
                              hint: entry.value,
                              active: format == entry.value,
                              onTap: () =>
                                  setDialogState(() => format = entry.value),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          AppDialogButton(label: 'Cancel', onTap: Get.back),
          AppDialogButton(
            label: 'Compress',
            primary: true,
            onTap: () {
              final String name = textController.text;
              Get.back();
              controller.compressEntries(targets, archiveName: name, format: format);
            },
          ),
        ],
      ),
    );
  }

  /// Format id mapped to the file extension it produces.
  static const Map<String, String> _archiveFormats = {
    'ZIP': 'zip',
    'TAR': 'tar',
    'TAR.GZ': 'tar.gz',
  };

  String _defaultArchiveName(String fileName) {
    const List<String> suffixes = ['.zip', '.tar.gz', '.tgz', '.tar'];
    final String lower = fileName.toLowerCase();

    for (final suffix in suffixes) {
      if (lower.endsWith(suffix)) {
        return fileName.substring(0, fileName.length - suffix.length);
      }
    }

    return fileName;
  }

  void _showCreateFolderDialog(BuildContext context) {
    final TextEditingController textController = TextEditingController();

    showAppDialog(
      builder: (_) => AppDialog(
        title: 'New folder',
        width: 360,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'Example: Projects',
            ),
            onSubmitted: (value) {
              Get.back();
              controller.createDirectory(value);
            },
          ),
        ),
        actions: [
          AppDialogButton(label: 'Cancel', onTap: Get.back),
          AppDialogButton(
            label: 'Create',
            primary: true,
            onTap: () {
              final String name = textController.text;
              Get.back();
              controller.createDirectory(name);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final bool searching = controller.searchQuery.value.trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.folder_open,
            size: 42,
            color: context.colors.textFaint,
          ),
          const SizedBox(height: 12),
          Text(
            searching ? 'No matching items' : 'This folder is empty',
            style: TextStyle(
              fontSize: 12.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 42,
              color: context.colors.textFaint,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to open directory',
              style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.refreshDirectory,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveFormatSegment extends StatelessWidget {
  const _ArchiveFormatSegment({
    required this.label,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Creates a $hint archive',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: active ? context.colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
                color: active
                    ? context.colors.accentContent
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
