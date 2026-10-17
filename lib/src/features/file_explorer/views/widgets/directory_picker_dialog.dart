import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/directory_picker_controller.dart';

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
    return AlertDialog(
      title: const Text('Pilih folder tujuan'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.only(left: 4, right: 4),
              decoration: BoxDecoration(
                color: AppColors.window,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Obx(
                () => Row(
                  children: [
                    IconButton(
                      onPressed: pickerController.isRoot
                          ? null
                          : pickerController.goToParent,
                      icon: const Icon(Icons.arrow_upward, size: 15),
                      tooltip: 'Folder induk',
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
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
                  color: AppColors.window,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (pickerController.directories.isEmpty) {
                    return const Center(
                      child: Text(
                        'Tidak ada subfolder',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textFaint,
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
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        FilledButton(
          onPressed: pickerController.selectCurrentDirectory,
          child: const Text('Pilih folder ini'),
        ),
      ],
    );
  }
}

class _FolderRow extends StatefulWidget {
  const _FolderRow({
    required this.name,
    required this.onTap,
    required this.onSelect,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onSelect,
        child: Container(
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 15, color: AppColors.folder),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 15,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
