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

  /// Forgets the query and its matches; options are kept.
  void clear() {
    query = '';
    matches = const [];
    currentIndex = noMatch;
  }

  /// The text a find should start with when [selected] is selected: the
  /// selection itself, unless it spans lines.
  static String seedFrom(String selected) =>
      selected.contains('\n') ? '' : selected;

  /// Searches [text] for [newQuery], selecting the first match at or after
  /// [fromOffset], wrapping to the first match in [text].
  void run(String text, String newQuery, {int fromOffset = 0}) {
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
    final atOrAfter = matches.indexWhere((start) => start >= fromOffset);
    currentIndex = atOrAfter == noMatch && hasMatches ? 0 : atOrAfter;
  }

  /// Searches [text] again for [query], since it may have been edited,
  /// and selects the first match starting after [offset], wrapping to the
  /// first; [backward] selects the last match starting before [offset],
  /// wrapping to the last.
  void step(String text, int offset, {bool backward = false}) {
    run(text, query);
    if (!hasMatches) return;
    if (backward) {
      final before = matches.lastIndexWhere((start) => start < offset);
      currentIndex = before == noMatch ? matches.length - 1 : before;
    } else {
      final after = matches.indexWhere((start) => start > offset);
      currentIndex = after == noMatch ? 0 : after;
    }
  }

  /// [text] with every occurrence of [query] replaced by [replacement],
  /// and how many were replaced; an occurrence overlapping the one before
  /// it is left as is.
  static ({String text, int count}) replaceAll(
    String text,
    String query,
    String replacement, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    if (query.isEmpty) return (text: text, count: 0);
    final buffer = StringBuffer();
    var copiedTo = 0;
    var count = 0;
    for (final start in findMatches(
      text,
      query,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    )) {
      if (start < copiedTo) continue;
      buffer
        ..write(text.substring(copiedTo, start))
        ..write(replacement);
      copiedTo = start + query.length;
      count++;
    }
    buffer.write(text.substring(copiedTo));
    return (text: buffer.toString(), count: count);
  }

  /// Confirmation that [count] occurrences were replaced, naming the
  /// [fileCount] files when more than one.
  static String replacedMessage(int count, {int fileCount = 1}) {
    final occurrences = '$count occurrence${count == 1 ? '' : 's'}';
    return fileCount == 1
        ? 'Replaced $occurrences'
        : 'Replaced $occurrences in $fileCount files';
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
