import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/health_check.dart';
import 'package:fide/models/quality_issue.dart';

/// Project health checks: the lock file, build logs and large files. A
/// failed check is one of the project's quality [issues]; none changes
/// fCheck's quality score.
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

  /// The failed checks as the issues the project's quality lists, the
  /// files they name located under [rootPath] (the project folder) when
  /// known.
  List<QualityIssue> issues(String? rootPath) => [
    if (!hasPubspecLock) HealthCheck.missingLock.issue(1, rootPath),
    if (buildErrors > 0) HealthCheck.buildErrors.issue(buildErrors, rootPath),
    if (buildWarnings > 0)
      HealthCheck.buildWarnings.issue(buildWarnings, rootPath),
    if (largeFiles.length > AppMetric.maxAllowedLargeFiles)
      HealthCheck.largeFiles.issue(
        largeFiles.length,
        rootPath,
        files: largeFiles,
      ),
  ];

  /// The indicators as JSON for the metrics cache.
  Map<String, dynamic> toJson() => {
    'hasPubspecLock': hasPubspecLock,
    'buildErrors': buildErrors,
    'buildWarnings': buildWarnings,
    'largeFiles': largeFiles,
    'hasDependencies': hasDependencies,
  };
}
