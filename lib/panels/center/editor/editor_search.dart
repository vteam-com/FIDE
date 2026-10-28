/// Find-in-file state for the editor: the query, its options, and where it
/// matches the text.
class EditorSearch {
  /// Value of [currentIndex] when no match is selected.
  static const int noMatch = -1;

  /// Pattern for word characters, used by [wholeWord].
  static final RegExp _wordCharacter = RegExp(r'\w');

  /// Whether letter case must match.
  bool caseSensitive = false;

  /// Whether matches must not touch other word characters.
  bool wholeWord = false;

  /// The text being searched for.
  String query = '';

  /// Start offset of each match, in order.
  List<int> matches = const [];

  /// Index into [matches] of the selected match, or [noMatch].
  int currentIndex = noMatch;

  /// Whether anything matched.
  bool get hasMatches => matches.isNotEmpty;

  /// Index of the match after the current one, wrapping to the first.
  int get nextIndex => (currentIndex + 1) % matches.length;

  /// Index of the match before the current one, wrapping to the last.
  int get previousIndex =>
      currentIndex <= 0 ? matches.length - 1 : currentIndex - 1;

  /// Forgets the query and its matches; options are kept.
  void clear() {
    query = '';
    matches = const [];
    currentIndex = noMatch;
  }

  /// Searches [text] for [newQuery], selecting the first match.
  void run(String text, String newQuery) {
    if (newQuery.isEmpty) {
      clear();
      return;
    }
    query = newQuery;
    matches = findMatches(
      text,
      newQuery,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
    currentIndex = matches.isEmpty ? noMatch : 0;
  }

  /// Start offsets of every occurrence of [query] in [text], overlapping
  /// occurrences included.
  static List<int> findMatches(
    String text,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    final needle = caseSensitive ? query : query.toLowerCase();
    final haystack = caseSensitive ? text : text.toLowerCase();
    final matches = <int>[];

    var index = haystack.indexOf(needle);
    while (index != -1) {
      final end = index + needle.length;
      final isWholeWord =
          (index == 0 || !_wordCharacter.hasMatch(haystack[index - 1])) &&
          (end == haystack.length || !_wordCharacter.hasMatch(haystack[end]));
      if (!wholeWord || isWholeWord) matches.add(index);
      index = haystack.indexOf(needle, index + 1);
    }
    return matches;
  }
}
