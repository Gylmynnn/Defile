import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';

/// Tracks one copy/move batch so the progress overlay can report progress and
/// let the user request cancellation between items.
///
/// Progress is drawn in an [OverlayEntry] rather than a route so closing it can
/// never pop the wrong screen out from under the running transfer.
class TransferProgress {
  TransferProgress({required this.title, required this.total});

  final String title;
  final int total;
  final ValueNotifier<int> completed = ValueNotifier<int>(0);
  final ValueNotifier<bool> cancelled = ValueNotifier<bool>(false);

  OverlayEntry? _entry;

  void advance() => completed.value += 1;

  bool get isCancelled => cancelled.value;

  void close() {
    _entry?.remove();
    _entry = null;
  }
}

/// Inserts the blocking progress overlay for [progress]. No-op when no overlay
/// is available (e.g. headless tests).
void showTransferProgress(TransferProgress progress) {
  final OverlayState? overlay = Get.key.currentState?.overlay;
  if (overlay == null) return;

  final OverlayEntry entry = OverlayEntry(
    builder: (_) => _TransferProgressOverlay(progress: progress),
  );

  progress._entry = entry;
  overlay.insert(entry);
}

class _TransferProgressOverlay extends StatelessWidget {
  const _TransferProgressOverlay({required this.progress});

  final TransferProgress progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.black54),
        ),
        Center(
          child: Container(
            width: 380,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.windowDeep,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
              border: Border.all(color: context.colors.cardBorder),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<int>(
                  valueListenable: progress.completed,
                  builder: (context, completed, _) {
                    final double ratio = progress.total == 0
                        ? 0
                        : completed / progress.total;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$completed of ${progress.total} items',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: context.colors.input,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: progress.cancelled,
                  builder: (context, cancelled, _) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          cancelled
                              ? 'Cancelling — finishing the current item…'
                              : 'You can cancel; items already transferred are kept.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CancelButton(
                        cancelled: cancelled,
                        onTap: () => progress.cancelled.value = true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.cancelled, required this.onTap});

  final bool cancelled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cancelled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          cancelled ? 'Cancelling…' : 'Cancel',
          style: TextStyle(
            fontSize: 12.5,
            color: cancelled
                ? context.colors.textFaint
                : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
