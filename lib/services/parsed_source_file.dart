import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// A Dart file of a project, parsed without resolving it, as fCheck's
/// analyzers read code, with what the `// ignore:` comments naming an
/// analyzer ([ignoreName]) skip: the code starting on the line one ends,
/// or the whole file when it is in the comments the file starts with.
///
/// Shared by the analyses FIDE evaluates before they move into fCheck.
class ParsedSourceFile {
  /// Parses [content], the file at [path], for the analyzer skipped by
  /// `// ignore: <ignoreName>` comments.
  ParsedSourceFile(this.path, String content, {required this.ignoreName})
    : unit = parseString(
        content: content,
        path: path,
        throwIfDiagnostics: false,
      ).unit,
      _lines = content.split('\n') {
    isIgnored = _startsIgnored(_lines);
  }

  /// File name endings of generated code, which no one fixes by hand.
  static const List<String> generatedSuffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.mocks.dart',
    '.pb.dart',
  ];

  /// A comment skipping analyzers on its line, the names after the colon.
  static final RegExp _lineIgnore = RegExp(r'//\s*ignore\s*:(.*)$');

  /// The analyzer's name in `// ignore:` comments, such as
  /// `fcheck_color_contrast`.
  final String ignoreName;

  /// Whether the file skips the analyzer altogether.
  late final bool isIgnored;

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

  /// The 1-based line [node] starts on: for a declaration, the line of
  /// its keyword or name, after its doc comment and annotations, where an
  /// ignore comment ends and a finding points.
  int lineOf(AstNode node) => unit.lineInfo
      .getLocation(
        node is AnnotatedNode
            ? node.firstTokenAfterCommentAndMetadata.offset
            : node.offset,
      )
      .lineNumber;

  /// Whether [line] has a comment skipping the analyzer.
  bool _skips(String line) {
    final names = _lineIgnore.firstMatch(line)?.group(1)?.split(',');
    return names?.any((name) => name.trim() == ignoreName) ?? false;
  }

  /// Whether the comments [lines] start with skip the analyzer.
  bool _startsIgnored(List<String> lines) {
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('//')) return false;
      if (_skips(trimmed)) return true;
    }
    return false;
  }

  /// Whether the file at [path] holds generated code.
  static bool isGenerated(String path) => generatedSuffixes.any(path.endsWith);

  /// The hand-written Dart files under [libPath], by path, for the
  /// analyzer named [ignoreName]; none when there is no such folder.
  static List<ParsedSourceFile> readAll(
    String libPath, {
    required String ignoreName,
  }) {
    final folder = Directory(libPath);
    if (!folder.existsSync()) return const [];
    final paths = [
      for (final entity in folder.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !isGenerated(entity.path))
          entity.path,
    ]..sort();
    return [
      for (final path in paths)
        ParsedSourceFile(
          path,
          File(path).readAsStringSync(),
          ignoreName: ignoreName,
        ),
    ];
  }
}
