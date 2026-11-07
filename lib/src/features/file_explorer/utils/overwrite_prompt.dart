import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../views/widgets/app_dialog.dart';
import 'app_dialog_route.dart';

/// User decision for a transfer (copy/move) that would replace existing items.
enum OverwriteDecision { replace, skip, cancel }

/// Asks how to handle [names] that already exist in the destination folder.
///
/// Returns null when the dialog is dismissed without choosing (same as
/// [OverwriteDecision.cancel]).
Future<OverwriteDecision?> showOverwritePrompt({
  required List<String> names,
  required bool anyDirectory,
}) {
  final bool single = names.length == 1;

  return showAppDialog<OverwriteDecision>(
    builder: (BuildContext context) {
      return AppDialog(
        title: single
            ? 'Replace "${names.first}"?'
            : 'Replace ${names.length} existing items?',
        width: 430,
        maxHeight: 460,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                single
                    ? 'An item with this name already exists in the '
                          'destination folder.'
                    : 'These items already exist in the destination folder:',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              if (!single) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final String name in names)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '• $name',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                anyDirectory
                    ? 'Replacing keeps the new version and deletes the old '
                          'one. Folders are replaced entirely, including '
                          'their contents.'
                    : 'Replacing keeps the new version and deletes the old '
                          'one.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textFaint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppDialogButton(
            label: 'Cancel',
            onTap: () => Get.back(result: OverwriteDecision.cancel),
          ),
          AppDialogButton(
            label: 'Skip existing',
            onTap: () => Get.back(result: OverwriteDecision.skip),
          ),
          AppDialogButton(
            label: 'Replace',
            danger: true,
            onTap: () => Get.back(result: OverwriteDecision.replace),
          ),
        ],
      );
    },
  );
}
