import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../controllers/file_explorer_controller.dart';

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
                    trailing: entry.isDirectory
                        ? const Icon(Icons.chevron_right)
                        : null,
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
