import 'dart:io';

import 'package:fide/services/spelling_analyzer.dart';

/// Replaces a misspelled word with its correction across a project's Dart
/// files, deterministically, keeping the casing of each occurrence.
///
/// A word matches where it starts a name or a part of one, as `avaiable`
/// in `avaiable` and `isAvaiable`, and not inside a longer word, as
/// `avaiables`.
class SpellingFixer {
  /// Creates the fixer.
  const SpellingFixer();

  /// The new content of each Dart file of the project at [projectPath]
  /// that has [word] in it, by absolute path, with [replacement] in its
  /// place; files without [word] are left out.
  Map<String, String> plan(
    String projectPath,
    String word,
    String replacement,
  ) {
    final changed = <String, String>{};
    for (final path in SpellingAnalyzer.checkedFiles(projectPath)) {
      final text = File(path).readAsStringSync();
      final updated = _replace(text, word, replacement);
      if (updated != text) changed[path] = updated;
    }
    return changed;
  }

  /// [text] with each match of [word] replaced by [replacement].
  static String _replace(String text, String word, String replacement) {
    final matches = RegExp(RegExp.escape(word), caseSensitive: false)
        .allMatches(text)
        .where((match) => _isWhole(text, match.start, match.end))
        .toList();
    if (matches.isEmpty) return text;
    final out = StringBuffer();
    var last = 0;
    for (final match in matches) {
      out
        ..write(text.substring(last, match.start))
        ..write(_casedLike(match.group(0)!, replacement));
      last = match.end;
    }
    return (out..write(text.substring(last))).toString();
  }

  /// Whether the match at [start] to [end] of [text] is a whole word or a
  /// whole part of a name: not preceded by a letter, unless it starts a
  /// camelCase part, and not followed by a lowercase letter.
  static bool _isWhole(String text, int start, int end) {
    final before = start == 0 ? '' : text[start - 1];
    final first = text[start];
    final startsPart =
        first == first.toUpperCase() && first != first.toLowerCase();
    if (_isLetter(before) && !startsPart) return false;
    final after = end < text.length ? text[end] : '';
    return !_isLowercase(after);
  }

  /// [replacement] in the casing of [matched]: all capitals, a capital
  /// first letter, or lowercase.
  static String _casedLike(String matched, String replacement) {
    if (matched.length > 1 && matched == matched.toUpperCase()) {
      return replacement.toUpperCase();
    }
    if (matched[0] == matched[0].toUpperCase() &&
        matched[0] != matched[0].toLowerCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }

  static bool _isLetter(String char) =>
      char.isNotEmpty && char.toLowerCase() != char.toUpperCase();

  static bool _isLowercase(String char) =>
      _isLetter(char) && char == char.toLowerCase();
}
