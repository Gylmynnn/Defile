import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../utils/formatters.dart';
import 'explorer_scope.dart';

class ExplorerStatusBar extends StatelessWidget {
  const ExplorerStatusBar({super.key, this.controller});

  final FileExplorerController? controller;

  @override
  Widget build(BuildContext context) {
    final FileExplorerController controller =
        this.controller ?? ExplorerScope.of(context);

    return Container(
      height: 25,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Obx(() {
        final entries = controller.visibleEntries;
        final int folders = entries.where((entry) => entry.isDirectory).length;
        final int files = entries.length - folders;
        final int selectedCount = controller.selection.length;
        final usage = controller.diskUsage.value;

        return Row(
          children: [
            Text(
              selectedCount > 0
                  ? '$selectedCount of ${entries.length} selected'
                  : '${entries.length} items ($folders folders, $files files)',
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.textSecondary,
              ),
            ),
            const Spacer(),
            if (usage != null) ...[
              _UsageBar(
                ratio: usage.totalBytes == BigInt.zero
                    ? 0
                    : usage.usedBytes.toDouble() / usage.totalBytes.toDouble(),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatBytes(usage.freeBytes)} free of ${formatBytes(usage.totalBytes)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _freeTint(usage, context.colors),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Color _freeTint(rust_system.DiskUsage usage, AppThemeColors colors) {
    if (usage.totalBytes == BigInt.zero) return colors.textSecondary;

    final double freeRatio =
        usage.freeBytes.toDouble() / usage.totalBytes.toDouble();

    if (freeRatio <= 0.1) return colors.danger;
    if (freeRatio <= 0.25) return colors.warning;
    return colors.textSecondary;
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 42,
        height: 4,
        child: LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 4,
          color: usageColor(ratio, context.colors),
          backgroundColor: context.colors.chip,
        ),
      ),
    );
  }
}

Color usageColor(double? ratio, AppThemeColors colors) {
  if (ratio == null) return colors.textSecondary;
  if (ratio >= 0.9) return colors.danger;
  if (ratio >= 0.75) return colors.warning;
  return colors.accent;
}
