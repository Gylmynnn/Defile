import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/portal_pick_controller.dart';
import '../../services/portal_file_chooser_service.dart';

/// Bottom banner shown while a portal FileChooser request is pending. The
/// explorer behind it stays fully usable for browsing and selecting; this
/// bar carries the request identity and the confirm/cancel actions.
class PortalPickBar extends StatelessWidget {
  const PortalPickBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final PortalPickController picker = Get.find<PortalPickController>();
      final int count = picker.queue.length;
      if (count == 0) return const SizedBox.shrink();

      final PortalPickRequest request = picker.queue.last;
      final colors = context.colors;

      // Live selection count of the focused tab (updates as rows are
      // picked) so the user can see what would be confirmed.
      int selected = 0;
      if (Get.isRegistered<ExplorerTabsController>()) {
        selected = Get.find<ExplorerTabsController>()
            .focusedController
            .selection
            .length;
      }

      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: colors.panel,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.accent, width: 1.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined, size: 18, color: colors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Defile is choosing ${request.isDirectoryMode ? 'a folder' : 'file(s)'}'
                    '${selected > 0 ? '  ·  $selected selected' : ''}'
                    '${request.appId.isEmpty ? '' : '  ·  ${request.appId}'}'
                    '${count > 1 ? '  ·  $count requests waiting' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textStrong, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: picker.cancelVisible,
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colors.textStrong, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: picker.confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.window,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    request.title,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
