import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../utils/formatters.dart';
import 'app_sidebar.dart';

class ExplorerStatusBar extends GetView<FileExplorerController> {
  const ExplorerStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
                  ? '$selectedCount dipilih dari ${entries.length} item'
                  : '${entries.length} item ($folders folder, $files file)',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
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
                style: TextStyle(fontSize: 11.5, color: _freeTint(usage)),
              ),
            ],
          ],
        );
      }),
    );
  }

  Color _freeTint(rust_system.DiskUsage usage) {
    if (usage.totalBytes == BigInt.zero) return AppColors.textSecondary;

    final double freeRatio =
        usage.freeBytes.toDouble() / usage.totalBytes.toDouble();

    if (freeRatio <= 0.1) return AppColors.danger;
    if (freeRatio <= 0.25) return AppColors.warning;
    return AppColors.textSecondary;
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
          color: usageColor(ratio),
          backgroundColor: const Color(0xFF2C3032),
        ),
      ),
    );
  }
}
