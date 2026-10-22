part of 'preview_panel.dart';

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
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DocumentPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      unawaited(_removeTempAfterFrame(_pdfPath));
      _load();
    }
  }

  @override
  void dispose() {
    _loadId++;
    unawaited(_removeTemp(_pdfPath));
    super.dispose();
  }

  Future<void> _removeTempAfterFrame(String? path) async {
    if (path == null) return;

    await WidgetsBinding.instance.endOfFrame;
    await _removeTemp(path);
  }

  Future<void> _removeTemp(String? path) async {
    if (path == null) return;

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _load() async {
    final int loadId = ++_loadId;
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

      if (!mounted || loadId != _loadId) {
        await _removeTemp(target.path);
        return;
      }

      setState(() {
        _pdfPath = target.path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || loadId != _loadId) return;

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
            Icon(Icons.description, size: 48, color: context.colors.textFaint),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Failed to load document',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.colors.textFaint),
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
            Icon(
              Icons.picture_as_pdf,
              size: 48,
              color: context.colors.textFaint,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: context.colors.textFaint),
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
            border: Border(top: BorderSide(color: context.colors.divider)),
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
                        color: context.colors.textSecondary,
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
                    value: formatBytes(widget.file.sizeBytes),
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
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
