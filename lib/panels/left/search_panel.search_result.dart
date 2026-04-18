part of 'search_panel.dart';

/// Represents `SearchResult`.
class SearchResult {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final int matchStart;
  final int matchEnd;

  SearchResult({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });
}
