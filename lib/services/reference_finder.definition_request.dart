part of 'reference_finder.dart';

/// Asks where the name at an offset of a file is declared; see
/// [ReferenceFinder.definition].
class DefinitionRequest extends ReferenceRequest<SearchResult> {
  /// Creates the request for the name at the caret [offset] of [filePath],
  /// whose text the editor shows as [content].
  const DefinitionRequest(this.filePath, this.offset, this.content);

  /// The file holding the name, as an absolute path.
  final String filePath;

  /// Where the caret is in [content].
  final int offset;

  /// The file's text as the editor shows it, unsaved edits included.
  final String content;

  @override
  bool get isLatestOnly => true;
}
