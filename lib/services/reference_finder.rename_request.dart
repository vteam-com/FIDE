part of 'reference_finder.dart';

/// Asks for the files renaming the declaration starting at 1-based line
/// and column of a file to [newName] changes; see
/// [ReferenceFinder.rename].
class RenameRequest extends DeclarationRequest<Map<String, String>> {
  /// Creates the request renaming the declaration at [line]:[column] of
  /// [filePath] to [newName].
  const RenameRequest(super.filePath, super.line, super.column, this.newName);

  /// The name the declaration and its uses get.
  final String newName;
}
