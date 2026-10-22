import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import 'app_button.dart';
import 'hover_region.dart';

/// Shared shell so every popup (settings, properties, pickers, prompts) uses
/// the same framing: deep window background, subtle border, titled header with
/// a close button, and an optional action footer.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.width,
    this.maxHeight,
    this.onClose,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double? width;
  final double? maxHeight;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final BoxConstraints constraints = maxHeight == null
        ? const BoxConstraints()
        : BoxConstraints(maxHeight: maxHeight!);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: Container(
          width: width,
          constraints: constraints,
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
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.cardBorder, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Container(height: 1, color: context.colors.divider),
              if (maxHeight != null) Flexible(child: content) else content,
              if (actions.isNotEmpty) ...[
                Container(height: 1, color: context.colors.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _withGaps(actions),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          AppDialogCloseButton(
            onTap: onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items) {
    final List<Widget> result = [];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) result.add(const SizedBox(width: 8));
      result.add(items[i]);
    }
    return result;
  }
}

class AppDialogButton extends StatelessWidget {
  const AppDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onTap: onTap,
      primary: primary,
      danger: danger,
    );
  }
}

class AppDialogCloseButton extends StatelessWidget {
  const AppDialogCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: hovered
                  ? context.colors.elevatedHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.close,
              size: 15,
              color: hovered
                  ? context.colors.textStrong
                  : context.colors.textFaint,
            ),
          ),
        );
      },
    );
  }
}
