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
import '../../controllers/file_explorer_controller.dart';
import '../../services/font_service.dart';
import '../../services/theme_service.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key, required this.availableWidth});

  final double availableWidth;

  static const double _minMainWidth = 360;
  static const double _minMainWidthSearching = 520;
  static const double _minPreviewWidth = 200;
  static const double _maxPreviewWidth = 800;
  static const double _resizeHandleWidth = 4;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FileExplorerController>();
    final themeService = Get.find<ThemeService>();

    return Obx(() {
      if (!themeService.previewEnabled.value) return const SizedBox.shrink();

      final double minMainWidth = controller.isSearching.value
          ? _minMainWidthSearching
          : _minMainWidth;
      final double maxWidth =
          (availableWidth - minMainWidth - _resizeHandleWidth).clamp(
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
      if (file == null) {
        return Container(
          width: width,
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
              onHorizontalDragStart: (_) {
                themeService.previewWidth.value = width;
              },
              onHorizontalDragUpdate: (details) {
                final newWidth = width - details.delta.dx;
                themeService.previewWidth.value = newWidth.clamp(
                  minWidth,
                  maxWidth,
                );
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
                child: Center(
                  child: Container(width: 1, color: AppColors.divider),
                ),
              ),
            ),
          ),
          Container(
            width: width,
            decoration: BoxDecoration(color: AppColors.surface),
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

    if (_isDocument(ext)) {
      return _DocumentPreview(file: file);
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

  bool _isDocument(String ext) {
    return ['doc', 'docx', 'odt', 'rtf'].contains(ext);
  }

  bool _isVideo(String ext) {
    return [
      'mp4',
      'webm',
      'mkv',
      'avi',
      'mov',
      'flv',
      'wmv',
      'm4v',
    ].contains(ext);
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
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: AppColors.textFaint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textFaint,
                    ),
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
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSubscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    try {
      MediaKit.ensureInitialized();
      final player = Player();
      _player = player;
      _videoController = VideoController(player);
      _errorSubscription = player.stream.error.listen((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Failed to load video';
        });
      });
      _load();
    } catch (_) {
      _loading = false;
      _error = 'Video preview requires mpv (install mpv)';
    }
  }

  @override
  void didUpdateWidget(_VideoPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _load();
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final player = _player;
    if (player == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await player.open(
        Media(Uri.file(widget.file.path).toString()),
        play: false,
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load video';
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

    final player = _player;
    final videoController = _videoController;
    if (player == null || videoController == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: Video(
            controller: videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data == true;

                  return Tooltip(
                    message: playing ? 'Pause' : 'Play',
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        iconSize: 21,
                        color: AppColors.accent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(9)),
                          ),
                        ),
                        onPressed: player.playOrPause,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration>(
                      stream: player.stream.duration,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds > 0
                            ? duration.inMilliseconds
                            : 1;
                        final value = position.inMilliseconds
                            .clamp(0, maxMs)
                            .toDouble();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 22,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  activeTrackColor: AppColors.accent,
                                  inactiveTrackColor: AppColors.elevated,
                                  thumbColor: AppColors.textStrong,
                                  overlayColor: AppColors.accent.withValues(
                                    alpha: 0.12,
                                  ),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                    elevation: 0,
                                    pressedElevation: 0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 11,
                                  ),
                                  trackShape:
                                      const RoundedRectSliderTrackShape(),
                                  tickMarkShape: SliderTickMarkShape.noTickMark,
                                  showValueIndicator: ShowValueIndicator.never,
                                ),
                                child: Slider(
                                  value: value,
                                  max: maxMs.toDouble(),
                                  padding: EdgeInsets.zero,
                                  onChanged: (next) => player.seek(
                                    Duration(milliseconds: next.round()),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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

class _DocumentPreview extends StatefulWidget {
  const _DocumentPreview({required this.file});

  final rust.FileEntry file;

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview> {
  String? _pdfPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DocumentPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _pdfPath = null;
      _error = null;
    });

    try {
      final bytes = await document.documentToPdf(path: widget.file.path);
      final stat = await File(widget.file.path).stat();
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/defile_previews',
      );
      await cacheDir.create(recursive: true);

      final target = File(
        '${cacheDir.path}/${widget.file.path.hashCode}_${stat.modified.millisecondsSinceEpoch}.pdf',
      );
      await target.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() {
        _pdfPath = target.path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load document';
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

    if (_pdfPath != null) {
      return _PdfPreview(
        key: ValueKey(_pdfPath),
        file: widget.file,
        resolvedPath: _pdfPath!,
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
              _error ?? 'Failed to load document',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({super.key, required this.file, this.resolvedPath});

  final rust.FileEntry file;
  final String? resolvedPath;

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

  String get _path => widget.resolvedPath ?? widget.file.path;

  @override
  void didUpdateWidget(_PdfPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path ||
        old.resolvedPath != widget.resolvedPath) {
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
      final count = await pdf.getPdfPageCount(path: _path);

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
        path: _path,
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
                    ? Image.memory(_pageImage!, fit: BoxFit.contain)
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
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
              if (_pageCount != null && _pageCount! > 1)
                const SizedBox(height: 8),
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
        final String content = _content ?? '';
        final int lineCount = content.split('\n').length;
        final String lineNumbers = List.generate(
          lineCount,
          (index) => '${index + 1}',
        ).join('\n');
        final TextStyle textStyle = TextStyle(
          fontSize: 11.5,
          color: AppColors.textPrimary,
          fontFamily: font.isEmpty ? 'monospace' : font,
          height: 1.4,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.divider)),
              ),
              child: Text(
                lineNumbers,
                textAlign: TextAlign.right,
                style: textStyle.copyWith(color: AppColors.textFaint),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: SelectableText(content, style: textStyle)),
          ],
        );
      }),
    );
  }
}
