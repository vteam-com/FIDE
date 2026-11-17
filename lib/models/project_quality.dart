import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';

/// The open project's one quality picture, the same wherever it shows (the
/// title bar's light bulb, the overview, the Info tab, the editor): fCheck's
/// score less what `dart analyze`'s diagnostics cost, over every issue
/// found by fCheck, `dart analyze` and the project's health checks.
class ProjectQuality {
  /// Creates the quality of [score] with [issues].
  const ProjectQuality({required this.score, required this.issues});

  /// Every problem found, the most pressing first.
  final List<QualityIssue> issues;

  /// fCheck's compliance score less `dart analyze`'s deduction, from 0 to
  /// [AppMetric.maxScore].
  final int score;

  /// Whether the score is below [AppMetric.maxScore] or anything was
  /// found.
  bool get needsAttention => score < AppMetric.maxScore || issues.isNotEmpty;

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
