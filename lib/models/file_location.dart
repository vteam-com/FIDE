import 'package:path/path.dart' as p;

/// A `path:line[:column]` reference found in command output, such as the
/// location of a compile error.
class FileLocation {
  /// A reference spanning [start] to [end] in its text, to [line] and
  /// [column] of the file at [path].
  const FileLocation({
    required this.start,
    required this.end,
    required this.path,
    required this.line,
    required this.column,
  });

  /// `path:line` with an optional `:column`; the path needs a file
  /// extension starting with a letter, so `127.0.0.1:8080` is not one.
  static final RegExp _pattern = RegExp(
    r'(?:file://)?(?<path>(?:[A-Za-z]:)?[\w.\-~/\\]+\.[A-Za-z]\w*)'
    r':(?<line>\d+)(?::(?<column>\d+))?',
  );

  /// Offset of the reference in its text.
  final int start;

  /// Offset just past the reference in its text.
  final int end;

  /// Absolute, normalized path of the referenced file.
  final String path;

  /// 1-based line in the file.
  final int line;

  /// 1-based column in the file; 1 when the reference has none.
  final int column;

  /// References in [text] to files that [exists], in order; relative paths
  /// resolve against [baseDir] and are skipped when it is null.
  static List<FileLocation> findAll(
    String text, {
    required String? baseDir,
    required bool Function(String) exists,
  }) {
    final locations = <FileLocation>[];
    for (final match in _pattern.allMatches(text)) {
      final reference = match.namedGroup('path')!;
      final line = int.tryParse(match.namedGroup('line')!);
      final column = int.tryParse(match.namedGroup('column') ?? '1');
      if (line == null || column == null) continue;
      final String path;
      if (p.isAbsolute(reference)) {
        path = p.normalize(reference);
      } else if (baseDir != null) {
        path = p.normalize(p.join(baseDir, reference));
      } else {
        continue;
      }
      if (!exists(path)) continue;
      locations.add(
        FileLocation(
          start: match.start,
          end: match.end,
          path: path,
          line: line,
          column: column,
        ),
      );
    }
    return locations;
  }
}
