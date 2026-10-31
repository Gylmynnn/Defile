/// Lightweight, dependency-free syntax tokenizer for the file preview.
///
/// Produces kind-tagged tokens per line; the preview maps kinds onto
/// `context.colors` at build time so highlighting always follows the active
/// palette and accent preset. Regex-based rather than a full parser — good
/// enough for preview purposes and fast enough for the 1MB preview budget.
library;

/// Semantic classes a token can belong to. The preview maps each kind to a
/// theme color (see `_TextPreviewState`).
enum CodeTokenKind {
  plain,
  comment,
  string,
  number,
  keyword,
  type,
  func,
  property,
  tag,
  attr,
  punct,
  heading,
  codeSpan,
  emphasis,
  link,
  added,
  removed,
}

/// A piece of text and what it is.
class CodeToken {
  const CodeToken(this.kind, this.text);

  final CodeTokenKind kind;
  final String text;
}

/// A label for the preview header, e.g. `dart` or `makefile`.
String codeLanguageLabel(String fileName) {
  final String lower = fileName.toLowerCase();
  if (kTextFileNames.contains(lower)) return lower;
  final String ext = _extensionOf(lower);
  if (_codeFamilies.containsKey(ext)) return ext;
  return 'text';
}

class CodeHighlighter {
  CodeHighlighter._(this._lang);

  /// Returns a highlighter for [fileName], or null when the file should be
  /// rendered as plain text (unknown type, logs, data dumps).
  static CodeHighlighter? forFileName(String fileName) {
    final String lower = fileName.toLowerCase();

    if (kTextFileNames.contains(lower)) {
      if (lower == 'makefile') return CodeHighlighter._(_makefileLang);
      if (lower == 'dockerfile') return CodeHighlighter._(_dockerfileLang);
      // LICENSE, CHANGELOG, .gitignore ... — plain text is fine.
      return null;
    }

    final String ext = _extensionOf(lower);
    if (kPlainPreviewExtensions.contains(ext)) return null;
    final _Lang? lang = switch (ext) {
      'makefile' => _makefileLang,
      'dockerfile' => _dockerfileLang,
      _ => _codeFamilies[ext],
    };
    if (lang == null) return null;
    return CodeHighlighter._(lang);
  }

  /// Tokenizes [content] into per-line token lists. Constructs that span
  /// lines (block comments, docstrings, fences) carry state between lines.
  List<List<CodeToken>> tokenize(String content) {
    if (_lang.markdown) return _tokenizeMarkdown(content);
    if (_lang.diff) return _tokenizeDiff(content);

    final List<List<CodeToken>> result = <List<CodeToken>>[];
    String? openBlock; // closing delimiter of an active block construct
    for (final String line in content.split('\n')) {
      result.add(_tokenizeLine(line, openBlock, (String? next) {
        openBlock = next;
      }));
    }
    return result;
  }

  final _Lang _lang;

  late final RegExp _scan = RegExp(
    <String>[
      if (_lang.markup) r'<!--',
      if (_lang.blockComment) r'/\*',
      for (final String c in _lang.lineComments) RegExp.escape(c),
      if (_lang.tripleQuotes) '"""|' "'''",
      r'"(?:\\.|[^"\\])*"|"[^"\\]*$',
      r"'(?:\\.|[^'\\])*'|'[^'\\]*$",
      r'`(?:\\.|[^`\\])*`?',
      r'(?<![\w.])0[xX][0-9a-fA-F_]+',
      r'(?<![\w.])\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?[uUlLfFdD]?',
      r'[A-Za-z_][A-Za-z0-9_]*',
      r'[+\-*/%=<>&|^~!?:;,.#@(){}[\]]',
    ].join('|'),
  );

  List<CodeToken> _tokenizeLine(
    String line,
    String? openBlock,
    void Function(String?) setOpen,
  ) {
    List<CodeToken> tokens = <CodeToken>[];

    // Continue an open block comment or docstring first.
    if (openBlock != null) {
      final int close = line.indexOf(openBlock);
      if (close == -1) {
        tokens.add(
          CodeToken(
            _lang.tripleQuotes ? CodeTokenKind.string : CodeTokenKind.comment,
            line,
          ),
        );
        return tokens;
      }
      final int end = close + openBlock.length;
      tokens.add(
        CodeToken(
          _lang.tripleQuotes ? CodeTokenKind.string : CodeTokenKind.comment,
          line.substring(0, end),
        ),
      );
      tokens.addAll(_scanSegment(line.substring(end)));
      setOpen(_open);
      return tokens;
    }

    tokens = _scanSegment(line);
    setOpen(_open);
    return tokens;
  }

  /// Carry state for constructs left unterminated at end of line.
  String? _open;

  List<CodeToken> _scanSegment(String segment) {
    _open = null;
    final List<CodeToken> tokens = <CodeToken>[];
    final StringBuffer plain = StringBuffer();
    int cursor = 0;

    void flushPlain() {
      if (plain.isEmpty) return;
      _appendTextTokens(tokens, plain.toString());
      plain.clear();
    }

    for (final RegExpMatch match in _scan.allMatches(segment)) {
      if (match.start < cursor) continue;
      final String text = segment.substring(match.start, match.end);

      if (match.start > cursor) {
        plain.write(segment.substring(cursor, match.start));
      }

      final String after = segment.substring(match.end).trimLeft();
      final String before = segment.substring(0, match.start).trimRight();

      // Whole-line comment — consume the rest of the line.
      if (_lang.lineComments.any((String c) => text.startsWith(c))) {
        flushPlain();
        tokens.add(
          CodeToken(CodeTokenKind.comment, segment.substring(match.start)),
        );
        return tokens;
      }

      // Block constructs: /* */ and <!-- --> and python docstrings.
      if (text == '/*' || text == '<!--' || text == '"""' || text == "'''") {
        flushPlain();
        final bool asString = text == '"""' || text == "'''";
        final String closing = text == '/*'
            ? '*/'
            : text == '<!--'
            ? '-->'
            : text;
        final int close = segment.indexOf(closing, match.start + text.length);
        if (close == -1) {
          tokens.add(
            CodeToken(
              asString ? CodeTokenKind.string : CodeTokenKind.comment,
              segment.substring(match.start),
            ),
          );
          _open = closing;
          return tokens;
        }
        final int end = close + closing.length;
        tokens.add(
          CodeToken(
            asString ? CodeTokenKind.string : CodeTokenKind.comment,
            segment.substring(match.start, end),
          ),
        );
        cursor = end;
        continue;
      }

      if (text.startsWith('"') || text.startsWith("'") || text.startsWith('`')) {
        flushPlain();
        tokens.add(CodeToken(CodeTokenKind.string, text));
        cursor = match.end;
        continue;
      }

      final String c = text[0];
      final int cu = c.codeUnitAt(0);
      final bool isDigit = cu >= 0x30 && cu <= 0x39;
      final bool isIdentStart =
          c == '_' || (cu >= 0x41 && cu <= 0x5A) || (cu >= 0x61 && cu <= 0x7A);

      flushPlain();

      if (isDigit) {
        tokens.add(CodeToken(CodeTokenKind.number, text));
      } else if (isIdentStart) {
        tokens.add(_classifyIdentifier(text, before, after));
      } else {
        tokens.add(CodeToken(CodeTokenKind.punct, text));
      }

      cursor = match.end;
    }

    if (cursor < segment.length) {
      plain.write(segment.substring(cursor));
    }
    flushPlain();

    return tokens;
  }

  CodeToken _classifyIdentifier(String text, String before, String after) {
    if (_lang.keywords.contains(text.toLowerCase())) {
      return CodeToken(CodeTokenKind.keyword, text);
    }

    final String next = after.isEmpty ? '' : after[0];

    if (_lang.markup) {
      if (before.endsWith('<') || before.endsWith('</')) {
        return CodeToken(CodeTokenKind.tag, text);
      }
      if (next == '=') return CodeToken(CodeTokenKind.attr, text);
    }

    if (next == '(') return CodeToken(CodeTokenKind.func, text);
    if (_lang.keyAfterColon && next == ':') {
      return CodeToken(CodeTokenKind.property, text);
    }
    // CamelCase reads as a type; SCREAMING_CASE reads as a constant.
    if (text.length > 1 &&
        text[0] == text[0].toUpperCase() &&
        text[0] != '_' &&
        !RegExp(r'^[A-Z0-9_]+$').hasMatch(text)) {
      return CodeToken(CodeTokenKind.type, text);
    }
    return CodeToken(CodeTokenKind.plain, text);
  }

  void _appendTextTokens(List<CodeToken> tokens, String text) {
    // Color punctuation runs; keep letters, digits and spaces plain.
    final RegExp splitter = RegExp(r'[^\w\s]+');
    int cursor = 0;
    for (final RegExpMatch m in splitter.allMatches(text)) {
      if (m.start > cursor) {
        tokens.add(
          CodeToken(CodeTokenKind.plain, text.substring(cursor, m.start)),
        );
      }
      tokens.add(CodeToken(CodeTokenKind.punct, m.group(0)!));
      cursor = m.end;
    }
    if (cursor < text.length) {
      tokens.add(CodeToken(CodeTokenKind.plain, text.substring(cursor)));
    }
  }

  // ---- markdown -----------------------------------------------------------

  List<List<CodeToken>> _tokenizeMarkdown(String content) {
    final List<List<CodeToken>> result = <List<CodeToken>>[];
    bool inFence = false;
    final RegExp fence = RegExp(r'^\s*(```|~~~)');

    for (final String line in content.split('\n')) {
      if (inFence) {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.codeSpan, line)]);
        if (fence.hasMatch(line)) inFence = false;
        continue;
      }
      if (fence.hasMatch(line)) {
        inFence = true;
        result.add(<CodeToken>[CodeToken(CodeTokenKind.comment, line)]);
        continue;
      }

      if (RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(line)) {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.heading, line)]);
        continue;
      }

      final List<CodeToken> tokens = <CodeToken>[];
      final RegExp inline = RegExp(
        r'`[^`]+`|\*\*[^*]+\*\*|__[^_]+__|\*[^*\s][^*]*\*|_[^_\s][^_]*_|\[[^\]]*\]\([^)]*\)|^>.*',
      );
      int cursor = 0;
      for (final RegExpMatch m in inline.allMatches(line)) {
        if (m.start > cursor) {
          tokens.add(
            CodeToken(CodeTokenKind.plain, line.substring(cursor, m.start)),
          );
        }
        final String text = m.group(0)!;
        if (text.startsWith('`')) {
          tokens.add(CodeToken(CodeTokenKind.codeSpan, text));
        } else if (text.startsWith('[')) {
          tokens.add(CodeToken(CodeTokenKind.link, text));
        } else if (text.startsWith('>')) {
          tokens.add(CodeToken(CodeTokenKind.comment, text));
        } else {
          tokens.add(CodeToken(CodeTokenKind.emphasis, text));
        }
        cursor = m.end;
      }
      if (cursor < line.length) {
        tokens.add(CodeToken(CodeTokenKind.plain, line.substring(cursor)));
      }
      result.add(tokens);
    }
    return result;
  }

  // ---- diff ---------------------------------------------------------------

  List<List<CodeToken>> _tokenizeDiff(String content) {
    final List<List<CodeToken>> result = <List<CodeToken>>[];
    for (final String line in content.split('\n')) {
      if (line.startsWith('+') && !line.startsWith('+++')) {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.added, line)]);
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.removed, line)]);
      } else if (line.startsWith('@@')) {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.keyword, line)]);
      } else {
        result.add(<CodeToken>[CodeToken(CodeTokenKind.plain, line)]);
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Language configuration
// ---------------------------------------------------------------------------

class _Lang {
  const _Lang({
    this.lineComments = const <String>[],
    this.blockComment = false,
    this.tripleQuotes = false,
    this.keyAfterColon = false,
    this.markup = false,
    this.markdown = false,
    this.diff = false,
    this.keywords = const <String>{},
  });

  final List<String> lineComments;
  final bool blockComment;
  final bool tripleQuotes;
  final bool keyAfterColon;
  final bool markup;
  final bool markdown;
  final bool diff;
  final Set<String> keywords;
}

const _Lang _makefileLang = _Lang(
  lineComments: <String>['#'],
  keywords: <String>{
    'all', 'clean', 'install', 'ifneq', 'ifeq', 'ifdef', 'ifndef', 'else',
    'endif', 'include', 'shell', 'wildcard', 'patsubst', 'subst', 'foreach',
    'call', 'eval', 'phony', 'rm', 'mkdir', 'cp', 'cd',
  },
);

const _Lang _dockerfileLang = _Lang(
  lineComments: <String>['#'],
  keywords: <String>{
    'from', 'as', 'run', 'cmd', 'label', 'expose', 'env', 'add', 'copy',
    'entrypoint', 'volume', 'user', 'workdir', 'arg', 'onbuild', 'stopsignal',
    'healthcheck', 'shell', 'maintainer',
  },
);

const _Lang _markupLang = _Lang(
  markup: true,
  keywords: <String>{
    'html', 'head', 'body', 'div', 'span', 'template', 'script', 'style',
    'link', 'meta', 'title', 'doctype',
  },
);

const _Lang _shellLang = _Lang(
  lineComments: <String>['#'],
  keywords: <String>{
    'if', 'else', 'elseif', 'endif', 'then', 'fi', 'for', 'foreach', 'in',
    'do', 'done', 'while', 'until', 'case', 'esac', 'function', 'return',
    'break', 'continue', 'param', 'begin', 'end', 'try', 'catch', 'finally',
    'throw', 'exit', 'local', 'set', 'echo', 'export', 'trap', 'shift',
    'true', 'false', 'null',
  },
);

/// Extension → language. Multi-extension families share one [_Lang] entry.
final Map<String, _Lang> _codeFamilies = <String, _Lang>{
  // C-like brace languages.
  for (final String ext in <String>{
    'c', 'h', 'cpp', 'hpp', 'cc', 'cxx', 'cs', 'java', 'kt', 'kts', 'swift',
    'dart', 'rs', 'go', 'js', 'jsx', 'ts', 'tsx', 'mjs', 'cjs', 'vue',
    'svelte', 'astro', 'php', 'scala', 'groovy', 'zig', 'sol', 'proto',
    'gradle', 'scss', 'sass', 'less', 'styl',
  })
    ext: const _Lang(
      lineComments: <String>['//'],
      blockComment: true,
      keywords: _cLikeKeywords,
    ),

  // Hash-comment languages.
  for (final String ext in <String>{
    'py', 'pyw', 'pyi', 'rb', 'sh', 'bash', 'zsh', 'fish', 'yaml', 'yml',
    'toml', 'ini', 'cfg', 'conf', 'env', 'properties', 'nix', 'pl', 'pm',
    'r', 'jl', 'cmake', 'gemspec', 'pp',
  })
    ext: _Lang(
      lineComments: <String>['#'],
      tripleQuotes: true,
      keywords: _hashKeywords,
    ),

  'lua': const _Lang(
    lineComments: <String>['--'],
    keywords: _hashKeywords,
  ),
  'vim': const _Lang(
    lineComments: <String>['"'],
    keywords: _hashKeywords,
  ),
  'sql': const _Lang(
    lineComments: <String>['--'],
    keywords: _sqlKeywords,
  ),
  'json': const _Lang(
    keyAfterColon: true,
    keywords: <String>{'true', 'false', 'null'},
  ),
  'jsonl': const _Lang(
    keyAfterColon: true,
    keywords: <String>{'true', 'false', 'null'},
  ),
  'lock': const _Lang(
    lineComments: <String>['#'],
    keyAfterColon: true,
    keywords: <String>{'true', 'false', 'null'},
  ),
  'bat': _shellLang,
  'cmd': _shellLang,
  'ps1': _shellLang,
  'html': _markupLang,
  'htm': _markupLang,
  'xhtml': _markupLang,
  'xml': _markupLang,
  'svg': _markupLang,
  'xsl': _markupLang,
  'plist': _markupLang,
  'css': const _Lang(
    lineComments: <String>['//'],
    blockComment: true,
    keyAfterColon: true,
    keywords: <String>{
      'media', 'import', 'keyframes', 'font-face', 'supports', 'charset',
      'important', 'root', 'mixin', 'include', 'extend', 'function', 'use',
      'forward', 'each', 'for', 'if', 'else', 'return',
    },
  ),
  'diff': const _Lang(diff: true),
  'patch': const _Lang(diff: true),
  'md': const _Lang(markdown: true),
  'mdx': const _Lang(markdown: true),
};

const Set<String> _cLikeKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
  'catch', 'class', 'const', 'continue', 'crate', 'debugger', 'default',
  'defer', 'delete', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
  'extension', 'extern', 'external', 'factory', 'false', 'final', 'finally',
  'fn', 'for', 'from', 'func', 'function', 'get', 'global', 'go', 'goto',
  'if', 'impl', 'implements', 'import', 'in', 'include', 'inline', 'int',
  'instanceof', 'interface', 'internal', 'is', 'late', 'let', 'loop', 'match',
  'mod', 'module', 'move', 'mut', 'namespace', 'new', 'nil', 'not', 'null',
  'operator', 'or', 'override', 'package', 'panic', 'partial', 'private',
  'protected', 'pub', 'public', 'raise', 'readonly', 'ref', 'register',
  'require', 'return', 'sealed', 'self', 'set', 'signed', 'sizeof', 'static',
  'struct', 'super', 'switch', 'synchronized', 'template', 'this', 'throw',
  'throws', 'trait', 'true', 'try', 'type', 'typedef', 'typeof', 'typename',
  'union', 'unsafe', 'unsigned', 'use', 'using', 'var', 'virtual', 'void',
  'volatile', 'when', 'where', 'while', 'with', 'yield',
};

const Set<String> _hashKeywords = {
  'and', 'as', 'assert', 'async', 'await', 'begin', 'break', 'case', 'class',
  'const', 'continue', 'def', 'defined', 'del', 'do', 'done', 'echo', 'elif',
  'else', 'elsif', 'end', 'ensure', 'except', 'exec', 'export', 'extends',
  'false', 'fi', 'finally', 'float', 'for', 'from', 'function', 'global',
  'if', 'import', 'in', 'int', 'is', 'lambda', 'let', 'list', 'local',
  'module', 'next', 'nil', 'none', 'not', 'null', 'or', 'pass', 'print',
  'raise', 'require', 'rescue', 'retry', 'return', 'self', 'set', 'source',
  'str', 'super', 'then', 'true', 'try', 'undef', 'unless', 'until', 'use',
  'when', 'while', 'with', 'yield',
};

const Set<String> _sqlKeywords = {
  'select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set',
  'delete', 'create', 'table', 'drop', 'alter', 'add', 'column', 'join',
  'left', 'right', 'inner', 'outer', 'full', 'cross', 'on', 'group', 'by',
  'order', 'having', 'limit', 'offset', 'union', 'all', 'distinct', 'and',
  'or', 'not', 'null', 'is', 'in', 'between', 'like', 'exists', 'primary',
  'key', 'foreign', 'references', 'index', 'view', 'default', 'unique',
  'check', 'constraint', 'begin', 'commit', 'rollback', 'transaction', 'as',
  'asc', 'desc', 'case', 'when', 'then', 'else', 'end', 'if', 'function',
  'procedure', 'trigger', 'return', 'true', 'false',
};

/// Files without a useful extension that are still text.
const Set<String> kTextFileNames = {
  'makefile',
  'dockerfile',
  'license',
  'licence',
  'changelog',
  'authors',
  'copying',
  'notice',
  'contributing',
  '.gitignore',
  '.gitattributes',
  '.editorconfig',
  '.dockerignore',
  '.npmrc',
  '.nvmrc',
  '.babelrc',
  '.prettierrc',
  '.eslintrc',
};

/// Never highlighted — rendered as plain text.
const Set<String> kPlainPreviewExtensions = {'log', 'csv', 'tsv', 'txt'};

String _extensionOf(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}
