import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:path/path.dart' as p;

/// One project health check, with how serious a failure is and the best
/// practice that fixes it; a failure is listed among the project's quality
/// issues.
enum HealthCheck {
  /// `pubspec.lock` is missing.
  missingLock(
    tone: StatusTone.warning,
    guidance:
        'Run `flutter pub get` to resolve the dependencies and write '
        '`pubspec.lock`; commit it so every build uses the same '
        'package versions.',
  ),

  /// Files are over the large-file threshold.
  largeFiles(
    tone: StatusTone.info,
    guidance:
        'Files over ${AppMetric.largeFileThresholdMb} MB slow down '
        'clones and builds: compress images and media, download '
        'large data at runtime, or track them with Git LFS.',
  );

  const HealthCheck({required this.tone, required this.guidance});

  /// The best practice that fixes a failed check, as Markdown.
  final String guidance;

  /// How serious a failed check is.
  final StatusTone tone;

  /// What is wrong when the check found [count] occurrences.
  String issueLabel(int count) => switch (this) {
    missingLock => 'Missing pubspec.lock',
    largeFiles => '$count large files',
  };

  /// The issue of the check failing [count] times, with how to fix it
  /// and, when [rootPath] (the project folder) is known, where each of
  /// the project-relative [files] it found is.
  QualityIssue issue(
    int count,
    String? rootPath, {
    List<String> files = const [],
  }) => QualityIssue(
    tone: tone,
    label: issueLabel(count),
    guidance: guidance,
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
