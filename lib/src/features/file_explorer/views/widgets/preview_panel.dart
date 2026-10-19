import 'dart:io';
import 'dart:typed_data';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/pdf.dart' as pdf;
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
          width: themeService.previewWidth.value,
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

      return Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newWidth = themeService.previewWidth.value - details.delta.dx;
                themeService.previewWidth.value = newWidth.clamp(280.0, 800.0);
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 1,
                    color: AppColors.divider,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: themeService.previewWidth.value,
            decoration: BoxDecoration(
              color: AppColors.surface,
            ),
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

    if (_isPdf(ext)) {
      return _PdfPreview(file: file);
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

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.file});

  final rust.FileEntry file;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  int? _pageCount;
  int _currentPage = 0;
  Uint8List? _pageImage;
  bool _loading = true;
  bool _loadingPage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PdfPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _currentPage = 0;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final count = await pdf.getPdfPageCount(path: widget.file.path);
      
      if (!mounted) return;
      setState(() => _pageCount = count);
      
      await _renderPage(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load PDF: $e';
      });
    }
  }

  Future<void> _renderPage(int pageIndex) async {
    setState(() => _loadingPage = true);
    
    try {
      final imageBytes = await pdf.renderPdfPage(
        path: widget.file.path,
        pageIndex: pageIndex,
        width: 1200, // ponytail: increase width for better quality/fill
      );
      
      if (!mounted) return;

      setState(() {
        _currentPage = pageIndex;
        _pageImage = Uint8List.fromList(imageBytes);
        _loading = false;
        _loadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingPage = false;
        _error = 'Failed to render page';
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _pageImage == null) {
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
            Icon(Icons.picture_as_pdf, size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SizedBox.expand(
                child: _pageImage != null
                    ? Image.memory(
                        _pageImage!,
                        fit: BoxFit.contain,
                      )
                    : const SizedBox.shrink(),
              ),
              if (_loadingPage)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            children: [
              if (_pageCount != null && _pageCount! > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage > 0 && !_loadingPage
                          ? () => _renderPage(_currentPage - 1)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_currentPage + 1} / $_pageCount',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage < _pageCount! - 1 && !_loadingPage
                          ? () => _renderPage(_currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              if (_pageCount != null && _pageCount! > 1) const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _InfoRow(label: 'Pages', value: '$_pageCount'),
                  const SizedBox(width: 16),
                  _InfoRow(
                    label: 'Size',
                    value: _formatSize(widget.file.sizeBytes.toInt()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
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
