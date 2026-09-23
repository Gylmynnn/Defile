import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:defile/src/rust/api/file_entry.dart' as rust;

import '../controllers/file_explorer_controller.dart';
import 'widgets/directory_picker_dialog.dart';

class FileExplorerPage extends GetView<FileExplorerController> {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defile'),
        actions: [
          IconButton(
            tooltip: 'Folder baru',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showCreateFolderDialog(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNavigationBar(context),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final error = controller.errorMessage.value;

              if (error != null) {
                return _buildError(error);
              }

              if (controller.entries.isEmpty) {
                return const Center(child: Text('Folder ini kosong'));
              }

              return ListView.builder(
                itemCount: controller.entries.length,
                itemBuilder: (context, index) {
                  final entry = controller.entries[index];

                  return ListTile(
                    leading: Icon(
                      entry.isDirectory
                          ? Icons.folder
                          : Icons.insert_drive_file,
                    ),
                    title: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(entry.isDirectory ? 'Folder' : 'File'),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Menu item',
                      onSelected: (value) async {
                        switch (value) {
                          case 'copy':
                            final destination = await Get.dialog<String>(
                              DirectoryPickerDialog(
                                initialPath: controller.currentPath.value,
                              ),
                            );

                            if (destination != null) {
                              await controller.copyEntry(
                                entry: entry,
                                destinationDirectory: destination,
                              );
                            }
                            break;

                          case 'move':
                            final destination = await Get.dialog<String>(
                              DirectoryPickerDialog(
                                initialPath: controller.currentPath.value,
                              ),
                            );

                            if (destination != null) {
                              await controller.moveEntry(
                                entry: entry,
                                destinationDirectory: destination,
                              );
                            }
                            break;
                          case 'rename':
                            _showRenameDialog(context, entry);
                            break;

                          case 'delete':
                            _showDeleteDialog(context, entry);
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => const [
                        PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy),
                              SizedBox(width: 12),
                              Text('Copy'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move),
                              SizedBox(width: 12),
                              Text('Move'),
                            ],
                          ),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_rename_outline),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => controller.openFile(entry),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    rust.FileEntry entry,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Hapus item?'),
        content: Text(
          'Apakah kamu yakin ingin menghapus '
          '"${entry.name}"?\n\n'
          'Folder hanya dapat dihapus jika kosong.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteEntry(entry);
    }
  }

  void _showRenameDialog(BuildContext context, rust.FileEntry entry) {
    final textController = TextEditingController(text: entry.name);

    Get.dialog(
      AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama baru'),
          onSubmitted: (value) {
            Get.back();
            controller.renameEntry(entry, value);
          },
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final newName = textController.text;
              Get.back();
              controller.renameEntry(entry, newName);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Folder baru'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama folder',
            hintText: 'Contoh: Projects',
          ),
          onSubmitted: (value) {
            Get.back();
            controller.createDirectory(value);
          },
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final name = textController.text;
              Get.back();
              controller.createDirectory(name);
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Obx(() {
      final breadcrumbs = controller.breadcrumbs;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              icon: const Icon(Icons.arrow_back),
              onPressed: controller.pathHistory.isEmpty
                  ? null
                  : controller.goBack,
            ),
            IconButton(
              tooltip: 'Folder induk',
              icon: const Icon(Icons.arrow_upward),
              onPressed: controller.currentPath.value == '/'
                  ? null
                  : controller.goToParent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final path in breadcrumbs)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => controller.navigateTo(path),
                            child: Text(
                              p.basename(path).isEmpty
                                  ? path
                                  : p.basename(path),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Gagal membuka direktori'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.refreshDirectory,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
