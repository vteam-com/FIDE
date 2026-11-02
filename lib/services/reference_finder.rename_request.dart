part of 'reference_finder.dart';

/// Asks for the files renaming the declaration starting at 1-based [line]
/// and [column] of [filePath] to [newName] changes; see
/// [ReferenceFinder.rename].
class RenameRequest extends ReferenceRequest<Map<String, String>> {
  /// Creates the request renaming the declaration at [line]:[column] of
  /// [filePath] to [newName].
  const RenameRequest(this.filePath, this.line, this.column, this.newName);

  /// The file declaring it, as an absolute path.
  final String filePath;

  /// 1-based line where the declaration starts.
  final int line;

  /// 1-based column where the declaration starts.
  final int column;

  /// The name the declaration and its uses get.
  final String newName;
}
