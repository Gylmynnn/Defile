part of 'preview_panel.dart';

class _TextPreview extends StatefulWidget {
  const _TextPreview({required this.file});

  final rust.FileEntry file;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  String? _content;
  List<List<CodeToken>>? _tokens;
  bool _wrap = true;
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
      _tokens = null;
      _content = null;
    });

    try {
      final file = File(widget.file.path);
      final stat = await file.stat();

      // Limit 1MB, add streaming for larger files.
      if (stat.size > 1024 * 1024) {
        setState(() {
          _loading = false;
          _error = 'File too large to preview (> 1MB)';
        });
        return;
      }

      final content = (await file.readAsString()).replaceAll('\t', '    ');
      if (!mounted) return;

      setState(() {
        _content = content;
        _tokens = CodeHighlighter.forFileName(widget.file.name)
            ?.tokenize(content);
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
    final String content = _content ?? '';
    final List<String> lines = content.split('\n');

    return Obx(() {
      final String font = fontService.fontFamily.value;
      final TextStyle textStyle = TextStyle(
        fontSize: 11.5,
        color: context.colors.textPrimary,
        fontFamily: font.isEmpty ? 'monospace' : font,
        height: 1.4,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(textStyle),
          Expanded(child: _buildBody(content, lines, textStyle)),
        ],
      );
    });
  }

  Widget _buildToolbar(TextStyle textStyle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              codeLanguageLabel(widget.file.name).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                color: context.colors.textFaint,
              ),
            ),
          ),
          Tooltip(
            message: _wrap ? 'Disable wrap' : 'Enable wrap',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _wrap = !_wrap),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _wrap ? Icons.wrap_text_rounded : Icons.short_text,
                  size: 15,
                  color: _wrap
                      ? context.colors.accent
                      : context.colors.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    String content,
    List<String> lines,
    TextStyle textStyle,
  ) {
    // Gutter width grows with the widest line number; 8.5 ≈ digit advance
    // of the mono fallback at 11.5px, plus fixed padding.
    final int digits = lines.length.toString().length;
    final double gutterWidth = 18 + digits * 8.5;

    if (!_wrap) {
      // Unwrapped: one wide horizontally-scrollable text block with a
      // static gutter column — each logical line is exactly one row, so a
      // joined number column stays aligned.
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: gutterWidth,
                padding: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: context.colors.divider),
                  ),
                ),
                child: Text(
                  List.generate(lines.length, (i) => '${i + 1}').join('\n'),
                  textAlign: TextAlign.right,
                  style: textStyle.copyWith(color: context.colors.textFaint),
                ),
              ),
              const SizedBox(width: 12),
              SelectableText(
                content,
                style: textStyle,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
      );
    }

    // Wrapped: virtualized per-line rows keep line numbers glued to the
    // first row of their logical line no matter how much it wraps.
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: gutterWidth,
                  padding: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: context.colors.divider),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.right,
                    style: textStyle.copyWith(
                      color: context.colors.textFaint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _spansForLine(index, lines, textStyle)),
                    style: textStyle,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<InlineSpan> _spansForLine(
    int index,
    List<String> lines,
    TextStyle base,
  ) {
    final List<CodeToken>? tokens = _tokens?[index];
    final List<CodeToken> line =
        tokens ?? <CodeToken>[CodeToken(CodeTokenKind.plain, lines[index])];

    return <InlineSpan>[
      for (final CodeToken token in line)
        TextSpan(text: token.text, style: _styleFor(token.kind, base)),
    ];
  }

  // Syntax colors derived from the active palette — no dedicated syntax
  // fields needed; light palettes get lighter tones for free.
  TextStyle _styleFor(CodeTokenKind kind, TextStyle base) {
    final colors = context.colors;
    switch (kind) {
      case CodeTokenKind.plain:
        return base;
      case CodeTokenKind.comment:
        return base.copyWith(
          color: colors.textFaint,
          fontStyle: FontStyle.italic,
        );
      case CodeTokenKind.string:
        return base.copyWith(color: colors.success);
      case CodeTokenKind.number:
        return base.copyWith(color: colors.warning);
      case CodeTokenKind.keyword:
        return base.copyWith(color: colors.dangerBright);
      case CodeTokenKind.type:
        return base.copyWith(color: colors.folder);
      case CodeTokenKind.func:
        return base.copyWith(color: colors.accent);
      case CodeTokenKind.property:
        return base.copyWith(color: colors.textSecondary);
      case CodeTokenKind.tag:
        return base.copyWith(color: colors.accent);
      case CodeTokenKind.attr:
        return base.copyWith(color: colors.folder);
      case CodeTokenKind.punct:
        return base.copyWith(color: colors.textSecondary);
      case CodeTokenKind.heading:
        return base.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w600,
        );
      case CodeTokenKind.codeSpan:
        return base.copyWith(color: colors.success);
      case CodeTokenKind.emphasis:
        return base.copyWith(
          color: colors.textStrong,
          fontWeight: FontWeight.w600,
        );
      case CodeTokenKind.link:
        return base.copyWith(
          color: colors.accent,
          decoration: TextDecoration.underline,
        );
      case CodeTokenKind.added:
        return base.copyWith(color: colors.success);
      case CodeTokenKind.removed:
        return base.copyWith(color: colors.dangerBright);
    }
  }
}
