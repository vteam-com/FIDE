part of 'color_contrast_analyzer.dart';

/// A Dart file of the project, parsed without resolving it, with what its
/// `// ignore: fcheck_color_contrast` comments skip, as in fCheck: the
/// code starting on the line one ends, or the whole file when it is in
/// the comments the file starts with.
class _SourceFile {
  _SourceFile(this.path, String content)
    : unit = parseString(
        content: content,
        path: path,
        throwIfDiagnostics: false,
      ).unit,
      _lines = content.split('\n'),
      isIgnored = _startsIgnored(content.split('\n'));

  /// File name endings of generated code, which no one fixes by hand.
  static const List<String> _generatedSuffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.mocks.dart',
    '.pb.dart',
  ];

  /// A comment skipping analyzers on its line, the names after the colon.
  static final RegExp _lineIgnore = RegExp(r'//\s*ignore\s*:(.*)$');

  /// Whether the file skips the analyzer altogether.
  final bool isIgnored;

  /// Absolute path of the file.
  final String path;

  /// The parsed code.
  final CompilationUnit unit;

  final List<String> _lines;

  /// Whether [node] or a node around it starts on a line that skips the
  /// analyzer, as fCheck's ignore comments do.
  bool isIgnoredAt(AstNode node) {
    if (isIgnored) return true;
    for (AstNode? current = node; current != null; current = current.parent) {
      if (_skips(_lines[lineOf(current) - 1])) return true;
    }
    return false;
  }

  /// The 1-based line [node] starts on.
  int lineOf(AstNode node) => unit.lineInfo.getLocation(node.offset).lineNumber;

  /// Whether [line] has a comment skipping the analyzer.
  static bool _skips(String line) {
    final names = _lineIgnore.firstMatch(line)?.group(1)?.split(',');
    return names?.any(
          (name) => name.trim() == ColorContrastAnalyzer.ignoreName,
        ) ??
        false;
  }

  /// Whether the comments [lines] start with skip the analyzer.
  static bool _startsIgnored(List<String> lines) {
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('//')) return false;
      if (_skips(trimmed)) return true;
    }
    return false;
  }

  /// The hand-written Dart files under [libPath], by path; none when there
  /// is no such folder.
  static List<_SourceFile> readAll(String libPath) {
    final folder = Directory(libPath);
    if (!folder.existsSync()) return const [];
    final paths = [
      for (final entity in folder.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_generatedSuffixes.any(entity.path.endsWith))
          entity.path,
    ]..sort();
    return [
      for (final path in paths)
        _SourceFile(path, File(path).readAsStringSync()),
    ];
  }
}
