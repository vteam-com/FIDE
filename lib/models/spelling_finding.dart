/// A word of the project's text that no known word matches, where it is,
/// and the closest known word, if one is near.
class SpellingFinding {
  /// Creates the finding of [word] at [line] of the file at [path].
  const SpellingFinding({
    required this.path,
    required this.line,
    required this.word,
    this.suggestion,
  });

  /// Absolute path of the file.
  final String path;

  /// Line the word is on, from 1.
  final int line;

  /// The unknown word, lowercase.
  final String word;

  /// The closest known word, lowercase; null when none is near.
  final String? suggestion;
}
