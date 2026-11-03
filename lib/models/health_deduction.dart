import 'package:fide/models/health_check.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:path/path.dart' as p;

/// What one [HealthCheck] found and what it costs the quality score; the
/// score, its breakdown and the health card all read the same list.
class HealthDeduction {
  /// Which check this is.
  final HealthCheck check;

  /// The rule, e.g. `Build errors (max 50 points)`.
  final String label;

  /// Occurrences found (1 for a missing lock file); 0 when all is well.
  final int count;

  /// Points subtracted from the score; 0 when the check costs nothing.
  final int points;

  /// Project-relative paths of the files the check found, when it names
  /// files; empty otherwise.
  final List<String> files;

  /// Creates a deduction.
  const HealthDeduction({
    required this.check,
    required this.label,
    required this.count,
    required this.points,
    this.files = const [],
  });

  /// Whether the check costs points.
  bool get isActive => points > 0;

  /// The issue the health card shows for this deduction, with how to fix
  /// it and, when [rootPath] (the project folder) is known, where each of
  /// its [files] is.
  QualityIssue toIssue(String? rootPath) => QualityIssue(
    tone: check.tone,
    label: check.issueLabel(count),
    guidance: check.guidance,
    rootPath: rootPath,
    findings: [
      if (rootPath != null)
        for (final file in files)
          QualityFinding(
            path: p.join(rootPath, file),
            line: 1,
            text: p.basename(file),
          ),
    ],
  );
}
