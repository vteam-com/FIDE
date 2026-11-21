import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';

/// The open project's one quality picture, the same wherever it shows (the
/// title bar's light bulb, the overview, the Info tab, the editor): fCheck's
/// score less what `dart analyze`'s diagnostics and the colors below WCAG 2
/// level AA cost, over every issue found by fCheck, `dart analyze`, the
/// color contrast analyzer and the project's health checks.
class ProjectQuality {
  /// Creates the quality of [score] with [issues].
  const ProjectQuality({required this.score, required this.issues});

  /// Every problem found, the most pressing first.
  final List<QualityIssue> issues;

  /// fCheck's compliance score less the deductions of `dart analyze` and
  /// the color contrast analyzer, from 0 to [AppMetric.maxScore].
  final int score;

  /// Whether the score is below [AppMetric.maxScore] or a warning or error
  /// was found; information, such as large files, lists without asking.
  bool get needsAttention =>
      score < AppMetric.maxScore ||
      issues.any((issue) => issue.tone.needsAttention);

  /// The score, then the most pressing issue on one line with how many
  /// others there are: the light bulb's tooltip.
  String get summary {
    final first = issues.firstOrNull;
    final others = issues.length - 1;
    return [
      'Quality $score%',
      if (first != null)
        others > 0 ? '${first.label} (+${others.localized} more)' : first.label,
    ].join('\n');
  }
}
