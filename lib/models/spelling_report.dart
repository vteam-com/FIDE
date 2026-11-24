import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/spelling_finding.dart';

/// The spelling of the project's Dart text: its words checked and those no
/// known word matches, as the Spelling card shows them.
class SpellingReport {
  /// Creates the report of [wordsChecked] words, [distinctWords] of them
  /// different, with [findings], in the project at [rootPath].
  const SpellingReport({
    required this.rootPath,
    required this.wordsChecked,
    required this.distinctWords,
    required this.findings,
  });

  /// Root of the project, for showing paths relative to it.
  final String rootPath;

  /// Words checked, counted once per occurrence.
  final int wordsChecked;

  /// Different words checked.
  final int distinctWords;

  /// Every occurrence of a word no known word matches.
  final List<SpellingFinding> findings;

  /// The distinct unknown words, in first-found order.
  List<String> get misspelled => {for (final f in findings) f.word}.toList();

  /// The score: the share of the distinct words checked that a known word
  /// matches, from 0 to [AppMetric.maxScore]; a project with no words scores
  /// the maximum.
  int get score {
    if (distinctWords == 0) return AppMetric.maxScore;
    final known = distinctWords - misspelled.length;
    return (AppMetric.maxScore * known / distinctWords).round().clamp(
      0,
      AppMetric.maxScore,
    );
  }
}
