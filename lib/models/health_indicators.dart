import 'package:fide/constants/constants.dart';

/// Project health checks and the quality score derived from them.
///
/// Each deduction is exposed on its own so the score breakdown dialog shows
/// exactly what [qualityScore] subtracted.
class HealthIndicators {
  /// Whether `pubspec.lock` exists.
  final bool hasPubspecLock;

  /// Build logs under `build/` that mention an error.
  final int buildErrors;

  /// Build logs under `build/` that mention a warning.
  final int buildWarnings;

  /// Project-relative paths of files over the large-file threshold.
  final List<String> largeFiles;

  /// Whether the pubspec declares dependencies.
  final bool hasDependencies;

  /// Creates the indicators for one analysis.
  const HealthIndicators({
    this.hasPubspecLock = false,
    this.buildErrors = 0,
    this.buildWarnings = 0,
    this.largeFiles = const [],
    this.hasDependencies = false,
  });

  /// Reads indicators saved by [toJson].
  factory HealthIndicators.fromJson(Map<String, dynamic> json) {
    return HealthIndicators(
      hasPubspecLock: json['hasPubspecLock'] as bool? ?? false,
      buildErrors: json['buildErrors'] as int? ?? 0,
      buildWarnings: json['buildWarnings'] as int? ?? 0,
      largeFiles: [...?(json['largeFiles'] as List?)?.cast<String>()],
      hasDependencies: json['hasDependencies'] as bool? ?? false,
    );
  }

  /// Points lost to build errors, capped.
  int get buildErrorDeduction =>
      (buildErrors * AppMetric.buildErrorDeductionPer).clamp(
        0,
        AppMetric.buildErrorDeductionMax,
      );

  /// Points lost to build warnings, capped.
  int get buildWarningDeduction =>
      (buildWarnings * AppMetric.buildWarningDeductionPer).clamp(
        0,
        AppMetric.buildWarningDeductionMax,
      );

  /// Whether there are more large files than allowed.
  bool get hasTooManyLargeFiles =>
      largeFiles.length > AppMetric.maxAllowedLargeFiles;

  /// Points lost to large files.
  int get largeFileDeduction =>
      hasTooManyLargeFiles ? AppMetric.largeFileThresholdMb : 0;

  /// Points lost to a missing lock file.
  int get missingLockDeduction =>
      hasPubspecLock ? 0 : AppMetric.missingLockDeduction;

  /// `AppMetric.maxScore` minus every deduction, never below zero.
  int get qualityScore =>
      (AppMetric.maxScore -
              missingLockDeduction -
              buildErrorDeduction -
              buildWarningDeduction -
              largeFileDeduction)
          .clamp(0, AppMetric.maxScore);

  /// The indicators as JSON for the metrics cache.
  Map<String, dynamic> toJson() => {
    'hasPubspecLock': hasPubspecLock,
    'buildErrors': buildErrors,
    'buildWarnings': buildWarnings,
    'largeFiles': largeFiles,
    'hasDependencies': hasDependencies,
  };
}
