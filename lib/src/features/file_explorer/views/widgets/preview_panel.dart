import 'dart:io';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/font_service.dart';
import '../../services/theme_service.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FileExplorerController>();
    final themeService = Get.find<ThemeService>();

    return Obx(() {
      if (!themeService.previewEnabled.value) return const SizedBox.shrink();

      final rust.FileEntry? file = controller.previewFile.value;
      if (file == null) {
        return Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.divider)),
          ),
          child: Center(
            child: Text(
              'No file selected',
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          ),
        );
      }

      return Container(
        width: 320,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(left: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewHeader(file: file),
            Expanded(child: _PreviewContent(file: file)),
          ],
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
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textStrong,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            file.isDirectory ? 'Folder' : _getFileType(file.name),
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getFileType(String name) {
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return ext.isEmpty ? 'File' : '$ext File';
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
              Icon(Icons.folder, size: 48, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(
                'Folder',
                style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      );
    }

    final String ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';

    if (_isImage(ext)) {
      return _ImagePreview(file: file);
    }

    if (_isVideo(ext)) {
      return _VideoPreview(file: file);
    }

    if (_isText(ext)) {
      return _TextPreview(file: file);
    }

    // ponytail: PDF preview needs lighter library, pdfium too heavy for static linking
    if (_isPdf(ext)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 48, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(
                'PDF preview',
                style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
              ),
              const SizedBox(height: 4),
              Text(
                'Double-click to open',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              'No preview available',
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImage(String ext) {
    return ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg'].contains(ext);
  }

  bool _isPdf(String ext) {
    return ext == 'pdf';
  }

  bool _isVideo(String ext) {
    return ['mp4', 'webm', 'mkv', 'avi', 'mov', 'flv', 'wmv', 'm4v'].contains(ext);
  }

  bool _isText(String ext) {
    return [
      'txt',
      'md',
      'json',
      'yaml',
      'yml',
      'toml',
      'xml',
      'html',
      'css',
      'js',
      'ts',
      'jsx',
      'tsx',
      'dart',
      'rs',
      'go',
      'py',
      'java',
      'c',
      'cpp',
      'h',
      'hpp',
      'sh',
      'bash',
      'zsh',
      'fish',
      'sql',
      'log',
      'conf',
      'ini',
      'env',
    ].contains(ext);
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file});

  final rust.FileEntry file;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(file.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 48, color: AppColors.textFaint),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.file});

  final rust.FileEntry file;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_VideoPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _controller?.dispose();
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final controller = VideoPlayerController.file(File(widget.file.path));
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load video';
      });
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                iconSize: 24,
                onPressed: _togglePlayPause,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final position = value.position.inSeconds;
                    final duration = value.duration.inSeconds;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                          value: duration > 0 ? position / duration : 0,
                          backgroundColor: AppColors.elevated,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TextPreview extends StatefulWidget {
  const _TextPreview({required this.file});

  final rust.FileEntry file;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  String? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_TextPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final file = File(widget.file.path);
      final stat = await file.stat();

      // ponytail: limit 1MB, add streaming for larger files
      if (stat.size > 1024 * 1024) {
        setState(() {
          _loading = false;
          _error = 'File too large to preview (> 1MB)';
        });
        return;
      }

      final content = await file.readAsString();
      if (!mounted) return;

      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load file';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );
    }

    final fontService = Get.find<FontService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final String font = fontService.fontFamily.value;

        return SelectableText(
          _content ?? '',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textPrimary,
            fontFamily: font.isEmpty ? 'monospace' : font,
            height: 1.4,
          ),
        );
      }),
    );
  }
}
