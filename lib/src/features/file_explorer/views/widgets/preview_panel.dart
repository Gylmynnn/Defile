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
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import 'explorer_scope.dart';

part 'preview_document.dart';
part 'preview_media.dart';
part 'preview_text.dart';

class PreviewPanel extends StatefulWidget {
  const PreviewPanel({super.key, required this.availableWidth});

  final double availableWidth;

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
      final bool enabled = themeService.previewEnabled.value;
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
      final double width = themeService.previewWidth.value.clamp(
        minWidth,
        maxWidth,
      );
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
                      themeService.previewWidth.value = width;
                    },
                    onHorizontalDragUpdate: (details) {
                      final newWidth = width - details.delta.dx;
                      themeService.previewWidth.value = newWidth.clamp(
                        minWidth,
                        maxWidth,
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
