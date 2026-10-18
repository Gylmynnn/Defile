import 'dart:async';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../controllers/file_explorer_controller.dart';
import 'widgets/app_dialog.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/context_menu.dart';
import 'widgets/directory_picker_dialog.dart';
import 'widgets/entry_views.dart';
import 'widgets/explorer_status_bar.dart';
import 'widgets/explorer_toolbar.dart';
import 'widgets/properties_dialog.dart';

class FileExplorerPage extends StatefulWidget {
  const FileExplorerPage({super.key});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  final GlobalKey _selectionLayerKey = GlobalKey();

  FileExplorerController get controller => Get.find<FileExplorerController>();

  bool _entryPressActive = false;
  String? _pendingOpenPath;

  bool _bandCandidate = false;
  bool _bandActive = false;
  Offset? _bandStart;
  Offset? _bandCurrent;
  final ValueNotifier<Rect?> _bandRect = ValueNotifier<Rect?>(null);
  Set<String> _bandBase = <String>{};
  final Map<String, Rect> _dragRects = <String, Rect>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _openSelected,
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              _renameSelected(context),
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true):
              _copySelected,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true):
              _cutSelected,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.keyA, control: true):
              _selectAll,
          const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              _refresh,
          const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
            shift: true,
          ): () =>
              _newFolder(context),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => controller.showSidebar.value
                    ? AppSidebar()
                    : const SizedBox.shrink(),
              ),
              VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: Column(
                  children: [
                    ExplorerToolbar(),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _handleBackgroundTap,
                              onSecondaryTapUp: (details) =>
                                  _showBackgroundMenu(
                                    context,
                                    details.globalPosition,
                                  ),
                              child: Obx(() => _buildContent(context)),
                            ),
                          ),
                          Positioned.fill(
                            child: Listener(
                              key: _selectionLayerKey,
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: _handleBandDown,
                              onPointerMove: _handleBandMove,
                              onPointerUp: _handleBandUp,
                              onPointerCancel: _handleBandUp,
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _SelectionBandPainter(_bandRect),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExplorerStatusBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _keyboardBlocked => controller.isSearching.value;

  @override
  void dispose() {
    _bandRect.dispose();
    super.dispose();
  }

  void _handleBackgroundTap() {
    _pendingOpenPath = null;
    controller.clearSelection();
  }

  void _handleBandDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;

    _bandCandidate = true;
    _bandStart = event.localPosition;
    _bandCurrent = event.localPosition;
  }

  void _handleBandMove(PointerMoveEvent event) {
    if (!_bandCandidate || _bandStart == null) return;

    if (_entryPressActive) {
      _bandCandidate = false;
      return;
    }

    _bandCurrent = event.localPosition;

    if (!_bandActive && (_bandCurrent! - _bandStart!).distance < 4) return;

    if (!_bandActive) {
      _bandActive = true;
      _dragRects.clear();

      final HardwareKeyboard keyboard = HardwareKeyboard.instance;
      _bandBase = keyboard.isControlPressed || keyboard.isMetaPressed
          ? controller.selection.map((entry) => entry.path).toSet()
          : <String>{};

      _collectDragRects();
    }

    _applyBandSelection();
  }

  void _handleBandUp(PointerEvent event) {
    _bandCandidate = false;
    _entryPressActive = false;

    if (!_bandActive) return;

    _bandActive = false;
    _dragRects.clear();

    _bandRect.value = null;
  }

  void _collectDragRects() {
    final RenderBox? layer =
        _selectionLayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (layer == null) return;

    for (final entry in controller.visibleEntries) {
      final RenderObject? object = EntryTileKey(entry.path).currentContext
          ?.findRenderObject();

      if (object is! RenderBox || !object.attached) continue;

      _dragRects[entry.path] =
          object.localToGlobal(Offset.zero, ancestor: layer) & object.size;
    }
  }

  void _applyBandSelection() {
    final Rect band = Rect.fromPoints(_bandStart!, _bandCurrent!);
    final Set<String> paths = <String>{..._bandBase};

    for (final tile in _dragRects.entries) {
      if (tile.value.overlaps(band)) paths.add(tile.key);
    }

    _bandRect.value = band;

    final List<rust.FileEntry> next = controller.visibleEntries
        .where((entry) => paths.contains(entry.path))
        .toList();

    if (_matchesSelection(next)) return;
    controller.selection.assignAll(next);
  }

  bool _matchesSelection(List<rust.FileEntry> next) {
    final List<rust.FileEntry> current = controller.selection;
    if (current.length != next.length) return false;
    for (int i = 0; i < next.length; i++) {
      if (current[i].path != next[i].path) return false;
    }
    return true;
  }

  Future<void> _openSelected() async {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection.toList();
    if (selected.isEmpty) return;

    for (final entry in selected) {
      await controller.openFile(entry);
    }
  }

  void _renameSelected(BuildContext context) {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.length != 1) return;

    _showRenameDialog(context, selected.first);
  }

  Future<void> _deleteSelected() async {
    if (_keyboardBlocked) return;

    await _removeSelection();
  }

  Future<void> _removeSelection() async {
    final List<rust.FileEntry> selected = controller.selection.toList();
    if (selected.isEmpty) return;

    if (controller.isCurrentInTrash) {
      final bool confirmed = await _confirm(
        title: 'Delete permanently?',
        message: selected.length == 1
            ? '"${selected.first.name}" will be permanently deleted. This action cannot be undone.'
            : '${selected.length} items will be permanently deleted. This action cannot be undone.',
        confirmLabel: 'Delete Permanently',
      );

      if (!confirmed) return;

      await controller.deletePermanently(selected);
      return;
    }

    await controller.trashEntries(selected);
  }

  void _copySelected() {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.isEmpty) return;

    controller.copyToClipboard(selected.toList());
  }

  void _cutSelected() {
    if (_keyboardBlocked) return;

    final List<rust.FileEntry> selected = controller.selection;
    if (selected.isEmpty) return;

    controller.cutToClipboard(selected.toList());
  }

  void _paste() {
    if (_keyboardBlocked) return;
    controller.pasteIntoCurrentDirectory();
  }

  void _selectAll() {
    if (_keyboardBlocked) return;
    controller.selectAll();
  }

  void _clearSelection() {
    if (_keyboardBlocked) return;
    _pendingOpenPath = null;
    controller.clearSelection();
  }

  void _refresh() {
    if (_keyboardBlocked) return;
    controller.refreshDirectory();
  }

  void _newFolder(BuildContext context) {
    if (_keyboardBlocked) return;
    _showCreateFolderDialog(context);
  }

  Widget _buildContent(BuildContext context) {
    final String? error = controller.errorMessage.value;
    if (error != null) {
      return _buildError(error);
    }

    final List<rust.FileEntry> entries = controller.visibleEntries;
    if (entries.isEmpty) {
      if (controller.isLoading.value) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }

      return _buildEmpty();
    }

    final Set<String> selectedPaths = controller.selection
        .map((entry) => entry.path)
        .toSet();

    void openMenu(rust.FileEntry entry, Offset position) {
      if (!controller.isSelected(entry)) {
        controller.selectOnly(entry);
      }

      _showEntryMenu(context, entry, position);
    }

    final Widget view = switch (controller.viewMode.value) {
      ExplorerViewMode.grid => EntryGridView(
        entries: entries,
        selectedPaths: selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
      ),
      ExplorerViewMode.list => EntryListView(
        entries: entries,
        selectedPaths: selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
      ),
      ExplorerViewMode.compact => EntryCompactView(
        entries: entries,
        selectedPaths: selectedPaths,
        onPress: _handleEntryPress,
        onTap: _handleEntryTap,
        onOpen: _handleEntryOpen,
        onMenu: openMenu,
      ),
    };

    return _LoadingShroud(loading: controller.isLoading.value, child: view);
  }

  void _handleEntryPress(rust.FileEntry entry) {
    _entryPressActive = true;

    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      controller.toggleSelection(entry);
      _pendingOpenPath = null;
      return;
    }

    if (keyboard.isShiftPressed) {
      controller.selectRangeTo(entry);
      _pendingOpenPath = null;
      return;
    }

    final bool wasSelected = controller.isSelected(entry);
    controller.selectOnly(entry);
    _pendingOpenPath = wasSelected ? entry.path : null;
  }

  void _handleEntryTap(rust.FileEntry entry) {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return;
    }

    if (_pendingOpenPath != entry.path) return;

    _pendingOpenPath = null;
    controller.openFile(entry);
  }

  void _handleEntryOpen(rust.FileEntry entry) {
    _pendingOpenPath = null;
    controller.selectOnly(entry);
    controller.openFile(entry);
  }

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
    final bool? result = await Get.dialog<bool>(
      AppDialog(
        title: title,
        width: 380,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

    Get.snackbar(
      'Path copied',
      entries.length == 1
          ? entries.first.path
          : '${entries.length} paths copied.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _pickDestination(
    List<rust.FileEntry> entries, {
    required bool move,
  }) async {
    final String? destination = await Get.dialog<String>(
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
    Get.dialog(PropertiesDialog(entry: entry));
  }

  void _showRenameDialog(BuildContext context, rust.FileEntry entry) {
    final TextEditingController textController = TextEditingController(
      text: entry.name,
    );

    Get.dialog(
      AppDialog(
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

  void _showCreateFolderDialog(BuildContext context) {
    final TextEditingController textController = TextEditingController();

    Get.dialog(
      AppDialog(
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
            color: AppColors.textFaint,
          ),
          const SizedBox(height: 12),
          Text(
            searching ? 'No matching items' : 'This folder is empty',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
            Icon(Icons.error_outline, size: 42, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              'Failed to open directory',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

class _LoadingShroud extends StatefulWidget {
  const _LoadingShroud({required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  State<_LoadingShroud> createState() => _LoadingShroudState();
}

class _LoadingShroudState extends State<_LoadingShroud> {
  static const Duration _delay = Duration(milliseconds: 150);

  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _LoadingShroud oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.loading && !oldWidget.loading) {
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _timer?.cancel();
      _timer = null;
      _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _visible = false;
    _timer?.cancel();
    _timer = Timer(_delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.loading && _visible)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.window.withValues(alpha: 0.55),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionBandPainter extends CustomPainter {
  _SelectionBandPainter(this.rect) : super(repaint: rect);

  final ValueListenable<Rect?> rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? band = rect.value;
    if (band == null) return;

    final RRect rrect = RRect.fromRectAndRadius(band, const Radius.circular(3));

    canvas.drawRRect(
      rrect,
      Paint()..color = AppColors.selectionBorder.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.selectionBorder.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionBandPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
