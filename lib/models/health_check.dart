import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/status_tone.dart';

/// How to clear build errors and warnings.
const String _fixBuildGuidance =
    'Build for the platform selected in the Execute panel, then pick '
    '**Fix Build** in the AI panel to have the errors of the last build '
    'fixed in the files.';

/// One project health check that can cost quality-score points, with how
/// serious a failure is and the best practice that fixes it.
enum HealthCheck {
  /// `pubspec.lock` is missing.
  missingLock(
    tone: StatusTone.warning,
    guidance:
        'Run `flutter pub get` to resolve the dependencies and write '
        '`pubspec.lock`; commit it so every build uses the same '
        'package versions.',
  ),

  /// Build logs mention errors.
  buildErrors(tone: StatusTone.error, guidance: _fixBuildGuidance),

  /// Build logs mention warnings.
  buildWarnings(tone: StatusTone.warning, guidance: _fixBuildGuidance),

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

  /// What is wrong when the check found [count] occurrences, as the
  /// health card reads.
  String issueLabel(int count) => switch (this) {
    missingLock => 'Missing pubspec.lock',
    buildErrors => '$count build errors',
    buildWarnings => '$count build warnings',
    largeFiles => '$count large files',
  };
}
