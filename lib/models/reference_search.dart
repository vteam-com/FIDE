import 'package:fide/models/search_result.dart';

/// Uses of a declaration to list in the Search panel.
class ReferenceSearch {
  /// Creates a listing of [results], the uses of [name].
  const ReferenceSearch({required this.name, required this.results});

  /// The declaration's name, shown as the search text.
  final String name;

  /// Where the declaration is used.
  final List<SearchResult> results;
}
