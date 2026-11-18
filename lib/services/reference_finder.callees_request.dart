part of 'reference_finder.dart';

/// Asks for what the function or method starting at 1-based line and
/// column of a file calls in the project; see [ReferenceFinder.callees].
class CalleesRequest extends DeclarationRequest<List<SearchResult>> {
  /// Creates the request for the declaration at [line]:[column] of
  /// [filePath].
  const CalleesRequest(super.filePath, super.line, super.column);

  @override
  bool get isLatestOnly => true;
}
