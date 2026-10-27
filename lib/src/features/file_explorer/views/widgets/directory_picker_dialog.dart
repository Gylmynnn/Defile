import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/directory_picker_controller.dart';
import 'app_dialog.dart';
import 'hover_region.dart';

/// Destination picker laid out like the main window: a places sidebar next to
/// the browsable folder list, so jumping to a bookmarked location or a drive
/// is one click instead of climbing parents.
class DirectoryPickerDialog extends StatefulWidget {
  const DirectoryPickerDialog({super.key, required this.initialPath});

  final String initialPath;

  @override
  State<DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<DirectoryPickerDialog> {
  late final DirectoryPickerController pickerController;

  @override
  void initState() {
    super.initState();
    pickerController = Get.put(
      DirectoryPickerController(Get.find<FileSystemService>()),
      tag: 'directory_picker_dialog',
    );
    pickerController.initialize(widget.initialPath);
  }

  @override
  void dispose() {
    Get.delete<DirectoryPickerController>(tag: 'directory_picker_dialog');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Choose destination folder',
      width: 680,
      maxHeight: 520,
      actions: [
        AppDialogButton(label: 'Cancel', onTap: Get.back),
        AppDialogButton(
          label: 'Choose this folder',
          primary: true,
          onTap: pickerController.selectCurrentDirectory,
        ),
      ],
      content: SizedBox(
        height: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerSidebar(picker: pickerController),
            Container(width: 1, color: context.colors.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPathBar(context),
                    const SizedBox(height: 10),
                    Expanded(child: _buildListing(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathBar(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: context.colors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Obx(
        () => Row(
          children: [
            IconButton(
              onPressed: pickerController.isRoot
                  ? null
                  : pickerController.goToParent,
              icon: const Icon(Icons.arrow_upward, size: 15),
              tooltip: 'Parent folder',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
            ),
            Expanded(
              child: Text(
                pickerController.currentPath.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: pickerController.loadDirectories,
              icon: const Icon(Icons.refresh, size: 15),
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListing(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Obx(() {
        if (pickerController.isLoading.value) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final String? error = pickerController.errorMessage.value;
        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          );
        }

        if (pickerController.directories.isEmpty) {
          return Center(
            child: Text(
              'No subfolders',
              style: TextStyle(fontSize: 12, color: context.colors.textFaint),
            ),
          );
        }

        String selectedPath = pickerController.currentPath.value;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: pickerController.directories.length,
          itemBuilder: (context, index) {
            final rust.FileEntry entry = pickerController.directories[index];

            return _FolderRow(
              name: entry.name,
              selected: entry.path == selectedPath,
              onTap: () => pickerController.openDirectory(entry),
              onSelect: () {
                pickerController.currentPath.value = entry.path;
                pickerController.selectCurrentDirectory();
              },
            );
          },
        );
      }),
    );
  }
}

/// Places column mirroring the main window's sidebar: quick access, bookmarked
/// folders and drives. Tapping one navigates the picker there; the shortcut
/// matching the current path is highlighted.
class _PickerSidebar extends StatelessWidget {
  const _PickerSidebar({required this.picker});

  final DirectoryPickerController picker;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      color: context.colors.sidebar,
      child: Obx(
        () {
          final List<rust_system.Place> homes = picker.homePlaces;
          final List<rust_system.Place> folders = picker.folderPlaces;
          final List<rust_system.Place> drives = picker.drivePlaces;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              for (final place in homes)
                _SidebarTile(
                  place: place,
                  icon: CupertinoIcons.house,
                  active: picker.isPlaceActive(place),
                  onTap: () => picker.openPlace(place),
                ),
              if (folders.isNotEmpty) ...[
                const _SidebarGroupLabel('Places'),
                for (final place in folders)
                  _SidebarTile(
                    place: place,
                    icon: CupertinoIcons.folder,
                    iconColor: context.colors.folder,
                    active: picker.isPlaceActive(place),
                    onTap: () => picker.openPlace(place),
                  ),
              ],
              if (drives.isNotEmpty) ...[
                const _SidebarGroupLabel('Drives'),
                for (final place in drives)
                  _SidebarTile(
                    place: place,
                    icon: Icons.storage,
                    active: picker.isPlaceActive(place),
                    onTap: () => picker.openPlace(place),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: context.colors.textFaint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: context.colors.divider)),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.place,
    required this.icon,
    required this.active,
    required this.onTap,
    this.iconColor,
  });

  final rust_system.Place place;
  final IconData icon;
  final Color? iconColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        final Color background = active
            ? context.colors.selection
            : hovered
            ? context.colors.hover
            : Colors.transparent;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 27,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active ? context.colors.selectionBorder : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active
                      ? context.colors.textPrimary
                      : (iconColor ?? context.colors.textSecondary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.name,
    required this.onTap,
    required this.onSelect,
    this.selected = false,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onTap,
          onDoubleTap: onSelect,
          child: Container(
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.rowSelected
                  : hovered
                  ? context.colors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, size: 15, color: context.colors.folder),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected
                          ? context.colors.textStrong
                          : context.colors.textPrimary,
                      fontWeight: selected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: context.colors.textFaint,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
