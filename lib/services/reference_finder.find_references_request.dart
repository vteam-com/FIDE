part of 'reference_finder.dart';

/// Asks for the uses of the declaration starting at 1-based line and
/// column of a file; see [ReferenceFinder.find].
class FindReferencesRequest extends DeclarationRequest<List<SearchResult>> {
  /// Creates the request for the declaration at [line]:[column] of
  /// [filePath].
  const FindReferencesRequest(super.filePath, super.line, super.column);

  @override
  bool get isLatestOnly => true;
}
