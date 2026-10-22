import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/directory_picker_controller.dart';
import 'app_dialog.dart';
import 'hover_region.dart';

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
      width: 520,
      maxHeight: 480,
      actions: [
        AppDialogButton(label: 'Cancel', onTap: Get.back),
        AppDialogButton(
          label: 'Choose this folder',
          primary: true,
          onTap: pickerController.selectCurrentDirectory,
        ),
      ],
      content: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 26,
                      ),
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
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
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
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textFaint,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: pickerController.directories.length,
                    itemBuilder: (context, index) {
                      final entry = pickerController.directories[index];

                      return _FolderRow(
                        name: entry.name,
                        onTap: () => pickerController.openDirectory(entry),
                        onSelect: () {
                          pickerController.currentPath.value = entry.path;
                          pickerController.selectCurrentDirectory();
                        },
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.name,
    required this.onTap,
    required this.onSelect,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onSelect;

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
              color: hovered ? context.colors.hover : Colors.transparent,
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
                      color: context.colors.textPrimary,
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
