/// One match of a project search.
class SearchResult {
  /// File the match is in.
  final String filePath;

  /// 1-based line of the match.
  final int lineNumber;

  /// The whole matching line.
  final String lineContent;

  /// Offset in [lineContent] where the match starts.
  final int matchStart;

  /// Offset in [lineContent] just past the match.
  final int matchEnd;

  /// Creates a match.
  const SearchResult({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });
}
