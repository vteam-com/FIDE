import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/health_check.dart';
import 'package:fide/models/quality_issue.dart';

/// Project health checks: the lock file and large files. A failed check
/// is one of the project's quality [issues]; none changes fCheck's quality
/// score. Build errors are `dart analyze`'s and the build's own.
class HealthIndicators {
  /// Whether `pubspec.lock` exists.
  final bool hasPubspecLock;

  /// Project-relative paths of files over the large-file threshold.
  final List<String> largeFiles;

  /// Creates the indicators of one check.
  const HealthIndicators({
    this.hasPubspecLock = false,
    this.largeFiles = const [],
  });

  /// The failed checks as the issues the project's quality lists, the
  /// files they name located under [rootPath] (the project folder) when
  /// known.
  List<QualityIssue> issues(String? rootPath) => [
    if (!hasPubspecLock) HealthCheck.missingLock.issue(1, rootPath),
    if (largeFiles.length > AppMetric.maxAllowedLargeFiles)
      HealthCheck.largeFiles.issue(
        largeFiles.length,
        rootPath,
        files: largeFiles,
      ),
  ];
}
