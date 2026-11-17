import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:path/path.dart' as p;

/// Runs a project's health checks: whether `pubspec.lock` exists and which
/// files are over the large-file threshold.
class HealthChecker {
  /// Creates the checker.
  const HealthChecker();

  /// Files over this many bytes are large.
  static const int _largeFileBytes =
      AppMetric.largeFileThresholdMb * AppMetric.bytesPerMegabyte;

  /// Checks the project at [projectPath].
  Future<HealthIndicators> check(String projectPath) async => HealthIndicators(
    hasPubspecLock: await File(ProjectPaths(projectPath).pubspecLock).exists(),
    largeFiles: await _largeFiles(projectPath),
  );

  /// Project-relative paths of the files over the large-file threshold.
  Future<List<String>> _largeFiles(String projectPath) async => [
    await for (final entity in ProjectFiles.entities(projectPath))
      if (entity is File && await _isLarge(entity))
        p.relative(entity.path, from: projectPath),
  ];

  /// Whether [file] is over the threshold; false when it can't be read,
  /// like a broken symlink.
  static Future<bool> _isLarge(File file) async {
    try {
      return await file.length() > _largeFileBytes;
    } on FileSystemException {
      return false;
    }
  }
}
