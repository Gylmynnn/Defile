import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    request.saveMode
                        ? Icons.save_outlined
                        : request.isDirectoryMode
                        ? Icons.folder_open_outlined
                        : Icons.upload_file_outlined,
                    size: 19,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.saveMode
                            ? (request.appId.isEmpty
                                  ? 'Saving a file'
                                  : 'Saving a file for ${request.appId}')
                            : (request.appId.isEmpty
                                  ? 'Choosing ${request.isDirectoryMode ? 'a folder' : 'file(s)'}'
                                  : 'Choosing ${request.isDirectoryMode ? 'a folder' : 'file(s)'} for ${request.appId}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (selected > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$selected selected',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              <String>[
                                request.title,
                                if (count > 1) '$count requests waiting',
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (request.saveMode) ...[
                  PointerInterceptor(
                    child: _SaveNameField(picker: picker, request: request),
                  ),
                  const SizedBox(width: 8),
                ],
                PointerInterceptor(
                  child: TextButton(
                    onPressed: picker.cancelVisible,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PointerInterceptor(
                  child: ElevatedButton.icon(
                    onPressed: picker.confirm,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      request.saveMode
                          ? 'Save'
                          : request.isDirectoryMode
                          ? 'Select Folder'
                          : 'Open',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.accentContent,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

/// The file-name entry for SaveFile requests. Stateful so typing does not
/// rebuild the bar; externally-set names (the request's suggested name on
/// present) are pushed into the field via [saveName].
class _SaveNameField extends StatefulWidget {
  const _SaveNameField({required this.picker, required this.request});

  final PortalPickController picker;
  final PortalPickRequest request;

  @override
  State<_SaveNameField> createState() => _SaveNameFieldState();
}

class _SaveNameFieldState extends State<_SaveNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.picker.saveName.value,
  );

  @override
  void initState() {
    super.initState();
    widget.picker.saveName.listen((String value) {
      if (!mounted || _controller.text == value) return;
      _controller.text = value;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 220,
      child: TextField(
        controller: _controller,
        onChanged: widget.picker.saveName.call,
        onSubmitted: (_) => widget.picker.confirm(),
        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'File name',
          hintStyle: TextStyle(fontSize: 12.5, color: colors.textFaint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.accent),
          ),
        ),
      ),
    );
  }
}
