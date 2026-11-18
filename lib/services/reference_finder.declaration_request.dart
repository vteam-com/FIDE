part of 'reference_finder.dart';

/// A question about the outline declaration starting at 1-based [line]
/// and [column] of [filePath], answered with a [T].
sealed class DeclarationRequest<T> extends ReferenceRequest<T> {
  /// Creates the request about the declaration at [line]:[column] of
  /// [filePath].
  const DeclarationRequest(this.filePath, this.line, this.column);

  /// The file declaring it, as an absolute path.
  final String filePath;

  /// 1-based line where the declaration starts.
  final int line;

  /// 1-based column where the declaration starts.
  final int column;
}
