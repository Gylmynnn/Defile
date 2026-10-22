part of 'preview_panel.dart';

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
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
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
          color: context.colors.textPrimary,
          fontFamily: font.isEmpty ? 'monospace' : font,
          height: 1.4,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: context.colors.divider),
                ),
              ),
              child: Text(
                lineNumbers,
                textAlign: TextAlign.right,
                style: textStyle.copyWith(color: context.colors.textFaint),
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
