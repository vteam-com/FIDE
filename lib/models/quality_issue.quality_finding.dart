/// One place in the project where a [QualityIssue] was found, such as a
/// hardcoded string on line 48 of a file.
class QualityFinding {
  /// Creates the finding at 1-based [line] of the file at absolute [path].
  const QualityFinding({
    required this.path,
    required this.line,
    required this.text,
  });

  /// 1-based line in the file.
  final int line;

  /// Absolute path of the file.
  final String path;

  /// What was found there, such as the string or symbol.
  final String text;
}
