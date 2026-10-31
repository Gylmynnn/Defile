import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:defile/src/rust/api/document.dart' as document;
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/pdf.dart' as pdf;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../theme/app_theme.dart';
import '../../services/font_service.dart';
import '../../services/theme_service.dart';
import '../../utils/code_highlighter.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import 'explorer_scope.dart';

part 'preview_document.dart';
part 'preview_media.dart';
part 'preview_text.dart';

class PreviewPanel extends StatefulWidget {
  const PreviewPanel({super.key, required this.availableWidth, this.enabledOverride});

  final double availableWidth;

  /// When given, the panel obeys this per-pane flag instead of the global
  /// ThemeService preview toggle (split view).
  final RxBool? enabledOverride;

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  static const double _minMainWidth = 360;
  static const double _minMainWidthSearching = 520;
  static const double _minPreviewWidth = 200;
  static const double _maxPreviewWidth = 800;
  static const double _resizeHandleWidth = 4;

  bool _resizing = false;

  @override
  Widget build(BuildContext context) {
    final controller = ExplorerScope.of(context);
    final themeService = Get.find<ThemeService>();

    return Obx(() {
      final bool paneMode = widget.enabledOverride != null;
      final bool enabled =
          widget.enabledOverride?.value ?? themeService.previewEnabled.value;
      final double minMainWidth = controller.isSearching.value
          ? _minMainWidthSearching
          : _minMainWidth;
      final double maxWidth =
          (widget.availableWidth - minMainWidth - _resizeHandleWidth).clamp(
            140.0,
            _maxPreviewWidth,
          );
      final double minWidth = maxWidth < _minPreviewWidth
          ? maxWidth
          : _minPreviewWidth;
      // Per-pane size in split view so resizing one pane never moves the
      // other's; the shared ThemeService knob otherwise.
      final double configuredWidth = paneMode
          ? controller.panePreviewWidth.value
          : themeService.previewWidth.value;
      final double width = configuredWidth.clamp(minWidth, maxWidth);
      final void Function(double) onResize = paneMode
          ? (value) => controller.panePreviewWidth.value = value
          : (value) => themeService.previewWidth.value = value;
      final rust.FileEntry? file = controller.previewFile.value;
      // Keep the handle reserved even when nothing is selected so the grid
      // does not shift on the first selection.
      final double panelWidth = width + _resizeHandleWidth;

      final Widget content = file == null
          ? Container(
              width: width,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(left: BorderSide(color: context.colors.divider)),
              ),
              child: Center(
                child: Text(
                  'No file selected',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.colors.textFaint,
                  ),
                ),
              ),
            )
          : Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      setState(() => _resizing = true);
                      onResize(width);
                    },
                    onHorizontalDragUpdate: (details) {
                      onResize(
                        (configuredWidth - details.delta.dx).clamp(
                          minWidth,
                          maxWidth,
                        ),
                      );
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() => _resizing = false);
                    },
                    onHorizontalDragCancel: () {
                      setState(() => _resizing = false);
                    },
                    child: Container(
                      width: _resizeHandleWidth,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 1,
                          color: context.colors.divider,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: width,
                  decoration: BoxDecoration(color: context.colors.surface),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreviewHeader(file: file),
                      Expanded(child: _PreviewContent(file: file)),
                    ],
                  ),
                ),
              ],
            );

      return AnimatedContainer(
        duration: _resizing ? Duration.zero : themeService.animationDuration,
        curve: Curves.easeOutCubic,
        width: enabled ? panelWidth : 0,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: panelWidth,
            maxWidth: panelWidth,
            child: IgnorePointer(ignoring: !enabled, child: content),
          ),
        ),
      );
    });
  }
}

/// Horizontal preview strip docked at the bottom of a side-by-side split
/// pane. The previewed file renders on the left, the name/type info on the
/// right, and the strip's height is draggable through its top edge.
class PreviewBottomPanel extends StatefulWidget {
  const PreviewBottomPanel({super.key, required this.availableWidth, this.enabledOverride});

  final double availableWidth;

  /// Per-pane flag override (split view), see [PreviewPanel.enabledOverride].
  final RxBool? enabledOverride;

  @override
  State<PreviewBottomPanel> createState() => _PreviewBottomPanelState();
}

class _PreviewBottomPanelState extends State<PreviewBottomPanel> {
  bool _resizing = false;

  @override
  Widget build(BuildContext context) {
    final controller = ExplorerScope.of(context);
    final themeService = Get.find<ThemeService>();

    return Obx(() {
      final bool paneMode = widget.enabledOverride != null;
      final bool enabled =
          widget.enabledOverride?.value ?? themeService.previewEnabled.value;
      final rust.FileEntry? file = controller.previewFile.value;

      final double configuredHeight = paneMode
          ? controller.panePreviewHeight.value
          : themeService.previewHeight.value;
      final double height = configuredHeight.clamp(110.0, 420.0);
      final void Function(double) onResize = paneMode
          ? (value) => controller.panePreviewHeight.value = value
          : (value) => themeService.previewHeight.value = value;

      // Split panes keep the strip mounted even with no selection — a quiet
      // placeholder holds the reserved space until a file is picked.
      final Widget content;
      if (file == null) {
        content = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.divider)),
          ),
          child: Center(
            child: Text(
              'No file selected',
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textFaint,
              ),
            ),
          ),
        );
      } else {
        final Widget infoPanel = Container(
          width: 200,
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(left: BorderSide(color: context.colors.divider)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textStrong,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                file.isDirectory ? 'Folder' : fileTypeLabel(file.name),
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textSecondary,
                ),
              ),
              if (!file.isDirectory) ...[
                const Spacer(),
                Text(
                  formatBytes(file.sizeBytes),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.colors.textFaint,
                  ),
                ),
              ],
            ],
          ),
        );

        content = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _PreviewContent(file: file)),
            infoPanel,
          ],
        );
      }

      final Widget strip = Column(
        children: [
          // Top resize handle (only meaningful once a file is previewed).
          if (file != null)
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) {
                  setState(() => _resizing = true);
                  onResize(height);
                },
                onVerticalDragUpdate: (details) {
                  onResize(
                    (configuredHeight - details.delta.dy).clamp(
                      110.0,
                      420.0,
                    ),
                  );
                },
                onVerticalDragEnd: (_) => setState(() => _resizing = false),
                onVerticalDragCancel: () => setState(() => _resizing = false),
                child: Container(
                  height: _resizing ? 6 : 4,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: _resizing ? double.infinity : 60,
                      height: 1,
                      color: context.colors.divider,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: content),
        ],
      );

      return AnimatedContainer(
        duration: _resizing ? Duration.zero : themeService.animationDuration,
        curve: Curves.easeOutCubic,
        height: enabled ? height : 0,
        decoration: BoxDecoration(color: context.colors.surface),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: height,
            maxHeight: height,
            child: IgnorePointer(ignoring: !enabled, child: strip),
          ),
        ),
      );
    });
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.file});

  final rust.FileEntry file;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textStrong,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            file.isDirectory ? 'Folder' : fileTypeLabel(file.name),
            style: TextStyle(
              fontSize: 11.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.file});

  final rust.FileEntry file;

  @override
  Widget build(BuildContext context) {
    if (file.isDirectory) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder, size: 48, color: context.colors.textFaint),
              const SizedBox(height: 12),
              Text(
                'Folder',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textFaint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRasterImageFile(file.name)) {
      return _ImagePreview(file: file);
    }

    if (isAudioFile(file.name)) {
      return _MediaPreview(
        key: const ValueKey('audio-preview'),
        file: file,
        showVideo: false,
      );
    }

    if (isVideoFile(file.name)) {
      return _MediaPreview(
        key: const ValueKey('video-preview'),
        file: file,
        showVideo: true,
      );
    }

    if (isTextFile(file.name)) {
      return _TextPreview(file: file);
    }

    if (isPdfFile(file.name)) {
      return _PdfPreview(file: file);
    }

    if (isConvertibleDocumentFile(file.name)) {
      return _DocumentPreview(file: file);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, size: 48, color: context.colors.textFaint),
            const SizedBox(height: 12),
            Text(
              'No preview available',
              style: TextStyle(fontSize: 12.5, color: context.colors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
