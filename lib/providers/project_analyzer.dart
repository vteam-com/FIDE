import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:yaml/yaml.dart';

/// Gathers project metrics (pubspec info, file and directory statistics,
/// health indicators) and derives a quality score from them.
///
/// Produces the metrics map persisted by `ProjectMetricsNotifier` and
/// rendered by the Info panel.
class ProjectAnalyzer {
  static const List<String> _trackedTopLevelDirectories = [
    'android',
    'ios',
    'web',
    'windows',
    'linux',
    'macos',
    'lib',
    'test',
  ];

  /// Creates a stateless analyzer.
  const ProjectAnalyzer();

  /// Analyzes the project at [projectPath] and returns its metrics map.
  Future<Map<String, dynamic>> analyze(String projectPath) async {
    final metrics = <String, dynamic>{};

    final pubspecFile = File('$projectPath/pubspec.yaml');
    final pubspecContent = pubspecFile.existsSync()
        ? pubspecFile.readAsStringSync()
        : null;
    if (pubspecContent != null) {
      _readPubspec(pubspecContent, metrics);
    }

    await _walkProjectTree(projectPath, metrics);
    await _analyzeHealthIndicators(projectPath, pubspecContent, metrics);
    _calculateQualityScore(metrics);

    return metrics;
  }

  /// Health checks that don't come from the main tree walk.
  Future<void> _analyzeHealthIndicators(
    String projectPath,
    String? pubspecContent,
    Map<String, dynamic> metrics,
  ) async {
    final indicators = metrics['healthIndicators'] as Map<String, dynamic>;

    indicators['hasPubspecLock'] = File('$projectPath/pubspec.lock')
        .existsSync();

    // Check for build warning/error logs
    final buildDir = Directory('$projectPath/build');
    if (buildDir.existsSync()) {
      int warningLogs = 0;
      int errorLogs = 0;

      await for (final entity in buildDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.log')) {
          final content = entity.readAsStringSync().toLowerCase();
          if (content.contains('error')) errorLogs++;
          if (content.contains('warning')) warningLogs++;
        }
      }

      indicators['buildWarnings'] = warningLogs;
      indicators['buildErrors'] = errorLogs;
    }

    if (pubspecContent != null) {
      indicators['hasDependencies'] = pubspecContent.contains('dependencies:');
    }
  }

  /// Scores the project out of `AppMetric.maxScore` from its health indicators.
  void _calculateQualityScore(Map<String, dynamic> metrics) {
    int score = AppMetric.maxScore;

    final healthIndicators =
        metrics['healthIndicators'] as Map<String, dynamic>?;

    if (healthIndicators == null) return;

    // Deduct for missing pubspec.lock
    if (!(healthIndicators['hasPubspecLock'] ?? false)) {
      score -= AppMetric.missingLockDeduction;
    }

    // Deduct for build errors
    final buildErrors = (healthIndicators['buildErrors'] ?? 0) as int;
    score -= (buildErrors * AppMetric.buildErrorDeductionPer).clamp(
      0,
      AppMetric.buildErrorDeductionMax,
    );

    // Deduct for warnings
    final buildWarnings = (healthIndicators['buildWarnings'] ?? 0) as int;
    score -= (buildWarnings * AppMetric.buildWarningDeductionPer).clamp(
      0,
      AppMetric.buildWarningDeductionMax,
    );

    // Deduct for large files
    final largeFiles = healthIndicators['largeFiles'] as List?;
    if (largeFiles != null &&
        largeFiles.length > AppMetric.maxAllowedLargeFiles) {
      score -= AppMetric.largeFileThresholdMb;
    }

    metrics['qualityScore'] = score.clamp(0, AppMetric.maxScore);
  }

  /// Maps each dependency name to its version, or a label for SDK and
  /// non-version (git, path, hosted) dependencies.
  Map<String, String> _describeDependencies(YamlMap deps) {
    final described = <String, String>{};
    deps.forEach((key, value) {
      if (value is String) {
        described[key as String] = value;
      } else if (value is YamlMap && value['sdk'] == 'flutter') {
        described[key as String] = 'Flutter SDK';
      } else {
        described[key as String] = 'Complex dependency';
      }
    });
    return described;
  }

  /// Reads name, version, description and dependencies from pubspec content.
  void _readPubspec(String content, Map<String, dynamic> metrics) {
    for (final line in content.split('\n')) {
      if (line.trim().startsWith('name:') &&
          !line.trim().startsWith('  name:')) {
        metrics['name'] = line.split(':').last.trim();
      }
      if (line.trim().startsWith('version:')) {
        metrics['version'] = line.split(':').last.trim();
      }
      if (line.trim().startsWith('description:')) {
        metrics['description'] = line.split(':').last.trim();
      }
    }

    final yamlMap = loadYamlDocument(content).contents as YamlMap;

    final deps = yamlMap['dependencies'] as YamlMap?;
    if (deps != null) {
      metrics['dependencies'] = _describeDependencies(deps);
    }

    final devDeps = yamlMap['dev_dependencies'] as YamlMap?;
    if (devDeps != null) {
      metrics['devDependencies'] = _describeDependencies(devDeps);
    }
  }

  /// Walks the project tree once, collecting per-extension file counts,
  /// top-level platform directory sizes, and files over the size threshold.
  Future<void> _walkProjectTree(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    const largeFileBytes =
        AppMetric.largeFileThresholdMb *
        AppMetric.fileSizeDivisor *
        AppMetric.fileSizeDivisor;
    final fileStats = <String, int>{};
    final structure = <String, int>{};
    final largeFiles = <String>[];

    await for (final entity in Directory(
      projectPath,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        fileStats[extension] = (fileStats[extension] ?? 0) + 1;
        try {
          if (await entity.length() > largeFileBytes) {
            largeFiles.add(entity.path.replaceFirst(projectPath, ''));
          }
        } catch (_) {
          // Skip files we can't read (like broken symlinks)
        }
      } else if (entity is Directory) {
        final pathSegments = entity.path
            .replaceFirst(projectPath, '')
            .split('/');
        if (pathSegments.length >= AppMetric.minDirPathDepth) {
          final category = pathSegments[1];
          if (_trackedTopLevelDirectories.contains(category)) {
            structure[category] = (structure[category] ?? 0) + 1;
          }
        }
      }
    }

    metrics['fileStats'] = fileStats;
    metrics['totalFiles'] = fileStats.values.fold(
      0,
      (sum, count) => sum + count,
    );
    metrics['directoryStructure'] = structure;
    metrics['healthIndicators'] = <String, dynamic>{'largeFiles': largeFiles};
  }
}
