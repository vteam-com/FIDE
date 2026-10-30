import 'package:path/path.dart' as p;

/// Ranks project files against a "Go to File" query the way VS Code's
/// Quick Open does: the query's letters must appear in order in the path,
/// and hits in the file name, next to each other or at word starts rank
/// higher.
class QuickOpenMatcher {
  /// Score of each matched letter.
  static const int _letterScore = 1;

  /// Extra score of a letter matched right after the previous one.
  static const int _consecutiveBonus = 5;

  /// Extra score of a letter matched at the start of a word.
  static const int _wordStartBonus = 3;

  /// Extra score when the whole query appears as is.
  static const int _substringBonus = 10;

  /// Extra score when the letters all match in the file name.
  static const int _nameBonus = 20;

  /// Extra score when the file name starts with the query.
  static const int _namePrefixBonus = 40;

  /// Characters after which a new word starts.
  static const String _wordSeparators = r'/\_-. ';

  /// Whitespace, which the query ignores.
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Score of [relativePath] for [query], higher is better; null when the
  /// query's letters do not all appear in order in it.
  static int? score(String relativePath, String query) {
    final needle = query.replaceAll(_whitespace, '').toLowerCase();
    if (needle.isEmpty) return 0;

    final name = p.basename(relativePath);
    final nameScore = _subsequenceScore(name, needle);
    if (nameScore != null) {
      return nameScore +
          _nameBonus +
          (name.toLowerCase().startsWith(needle) ? _namePrefixBonus : 0);
    }
    return _subsequenceScore(relativePath, needle);
  }

  /// [paths] matching [query], best first then shortest, at most [limit];
  /// all of [paths], in their order, for an empty query. Paths are scored
  /// relative to [rootPath].
  static List<String> rank(
    List<String> paths,
    String query, {
    required String rootPath,
    required int limit,
  }) {
    if (query.trim().isEmpty) return paths.take(limit).toList();

    final scored = <(String, int)>[
      for (final path in paths)
        if (score(p.relative(path, from: rootPath), query) case final score?)
          (path, score),
    ];
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      final byLength = a.$1.length.compareTo(b.$1.length);
      return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
    });
    return [for (final (path, _) in scored.take(limit)) path];
  }

  /// Score of the lowercase [needle]'s letters found in order in [text],
  /// leftmost first; null when one is missing.
  static int? _subsequenceScore(String text, String needle) {
    final lower = text.toLowerCase();
    var total = lower.contains(needle) ? _substringBonus : 0;
    var previous = -1;
    for (final letter in needle.split('')) {
      final index = lower.indexOf(letter, previous + 1);
      if (index < 0) return null;
      total += _letterScore;
      if (index == previous + 1 && previous >= 0) total += _consecutiveBonus;
      if (_isWordStart(text, index)) total += _wordStartBonus;
      previous = index;
    }
    return total;
  }

  /// Whether [text] starts a word at [index]: its start, after a
  /// separator, or a capital after a lowercase letter.
  static bool _isWordStart(String text, int index) {
    if (index == 0) return true;
    final before = text[index - 1];
    if (_wordSeparators.contains(before)) return true;
    final current = text[index];
    return current != current.toLowerCase() && before == before.toLowerCase();
  }
}
