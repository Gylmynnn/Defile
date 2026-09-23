import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/directory_picker_controller.dart';
import '../../controllers/file_explorer_controller.dart';

class DirectoryPickerDialog extends GetView<FileExplorerController> {
  const new({super.key, required this.initialPath});

  final String initialPath;

  @override
  Widget build(BuildContext context) {
    final pickerController = Get.put(
      DirectoryPickerController(controller.fileSystemService),
    );

    return AlertDialog(
      title: const Text('Pilih folder tujuan'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Obx(
              () => Row(
                children: [
                  IconButton(
                    onPressed: pickerController.isRoot
                        ? null
                        : pickerController.goToParent,
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Folder induk',
                  ),
                  Expanded(
                    child: Text(
                      pickerController.currentPath.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: pickerController.loadDirectories,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Obx(() {
                if (pickerController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (pickerController.directories.isEmpty) {
                  return const Center(child: Text('Tidak ada subfolder'));
                }

                return ListView.builder(
                  itemCount: pickerController.directories.length,
                  itemBuilder: (context, index) {
                    final entry = pickerController.directories[index];

                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(entry.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pickerController.openDirectory(entry),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        FilledButton(
          onPressed: pickerController.selectCurrentDirectory,
          child: const Text('Pilih folder'),
        ),
      ],
    );
  }
}
