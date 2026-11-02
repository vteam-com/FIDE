part of 'reference_finder.dart';

/// Asks for the uses of the declaration starting at 1-based [line] and
/// [column] of [filePath]; see [ReferenceFinder.find].
class FindReferencesRequest extends ReferenceRequest<List<SearchResult>> {
  /// Creates the request for the declaration at [line]:[column] of
  /// [filePath].
  const FindReferencesRequest(this.filePath, this.line, this.column);

  /// The file declaring it, as an absolute path.
  final String filePath;

  /// 1-based line where the declaration starts.
  final int line;

  /// 1-based column where the declaration starts.
  final int column;
}
