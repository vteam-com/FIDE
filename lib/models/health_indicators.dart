import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/health_check.dart';
import 'package:fide/models/health_deduction.dart';

/// Project health checks and the quality score derived from them.
///
/// [deductions] lists every check, so the score breakdown dialog and the
/// health card show exactly what [qualityScore] subtracted.
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

  /// Every health check with what it found and the points it costs, in
  /// the order the score breakdown lists them.
  List<HealthDeduction> get deductions => [
    HealthDeduction(
      check: HealthCheck.missingLock,
      label: 'Missing pubspec.lock',
      count: hasPubspecLock ? 0 : 1,
      points: hasPubspecLock ? 0 : AppMetric.missingLockDeduction,
    ),
    HealthDeduction(
      check: HealthCheck.buildErrors,
      label: 'Build errors (max ${AppMetric.buildErrorDeductionMax} points)',
      count: buildErrors,
      points: (buildErrors * AppMetric.buildErrorDeductionPer).clamp(
        0,
        AppMetric.buildErrorDeductionMax,
      ),
    ),
    HealthDeduction(
      check: HealthCheck.buildWarnings,
      label:
          'Build warnings (max ${AppMetric.buildWarningDeductionMax} points)',
      count: buildWarnings,
      points: (buildWarnings * AppMetric.buildWarningDeductionPer).clamp(
        0,
        AppMetric.buildWarningDeductionMax,
      ),
    ),
    HealthDeduction(
      check: HealthCheck.largeFiles,
      label:
          'Large files (>${AppMetric.maxAllowedLargeFiles} files over '
          '${AppMetric.largeFileThresholdMb}MB)',
      count: largeFiles.length,
      points: largeFiles.length > AppMetric.maxAllowedLargeFiles
          ? AppMetric.largeFilesDeduction
          : 0,
      files: largeFiles,
    ),
  ];

  /// `AppMetric.maxScore` minus every deduction, never below zero.
  int get qualityScore =>
      (AppMetric.maxScore -
              deductions.fold<int>(
                0,
                (sum, deduction) => sum + deduction.points,
              ))
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
