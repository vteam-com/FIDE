import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:yaml/yaml.dart';

/// Gathers project metrics (pubspec info, file and directory statistics,
/// health indicators) and derives a quality score from them.
///
/// Produces the [ProjectMetrics] persisted by `ProjectMetricsNotifier` and
/// rendered by the Info panel.
class ProjectAnalyzer {
  static final Set<String> _trackedTopLevelDirectories = {
    for (final platform in FlutterPlatform.values) platform.name,
    'lib',
    'test',
  };

  /// Creates a stateless analyzer.
  const ProjectAnalyzer();

  /// Analyzes the project at [projectPath].
  Future<ProjectMetrics> analyze(String projectPath) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    final pubspecContent = pubspecFile.existsSync()
        ? pubspecFile.readAsStringSync()
        : null;
    final pubspec = pubspecContent == null
        ? null
        : _readPubspec(pubspecContent);
    final tree = await _walkProjectTree(projectPath);
    final buildLogs = await _countBuildLogs(projectPath);

    return ProjectMetrics(
      name: pubspec?.name,
      version: pubspec?.version,
      description: pubspec?.description,
      dependencies: pubspec?.dependencies ?? const {},
      devDependencies: pubspec?.devDependencies ?? const {},
      fileStats: tree.fileStats,
      directoryStructure: tree.structure,
      health: HealthIndicators(
        hasPubspecLock: File('$projectPath/pubspec.lock').existsSync(),
        buildErrors: buildLogs.errors,
        buildWarnings: buildLogs.warnings,
        largeFiles: tree.largeFiles,
        hasDependencies: pubspecContent?.contains('dependencies:') ?? false,
      ),
    );
  }

  /// Counts the `.log` files under `build/` that mention errors and warnings.
  Future<({int errors, int warnings})> _countBuildLogs(
    String projectPath,
  ) async {
    final buildDir = Directory('$projectPath/build');
    var errors = 0;
    var warnings = 0;
    if (buildDir.existsSync()) {
      await for (final entity in buildDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.log')) {
          final content = entity.readAsStringSync().toLowerCase();
          if (content.contains('error')) errors++;
          if (content.contains('warning')) warnings++;
        }
      }
    }
    return (errors: errors, warnings: warnings);
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
  ({
    String? name,
    String? version,
    String? description,
    Map<String, String>? dependencies,
    Map<String, String>? devDependencies,
  })
  _readPubspec(String content) {
    String? name;
    String? version;
    String? description;
    for (final line in content.split('\n')) {
      if (line.trim().startsWith('name:') &&
          !line.trim().startsWith('  name:')) {
        name = line.split(':').last.trim();
      }
      if (line.trim().startsWith('version:')) {
        version = line.split(':').last.trim();
      }
      if (line.trim().startsWith('description:')) {
        description = line.split(':').last.trim();
      }
    }

    final yamlMap = loadYamlDocument(content).contents as YamlMap;
    final deps = yamlMap['dependencies'] as YamlMap?;
    final devDeps = yamlMap['dev_dependencies'] as YamlMap?;
    return (
      name: name,
      version: version,
      description: description,
      dependencies: deps == null ? null : _describeDependencies(deps),
      devDependencies: devDeps == null ? null : _describeDependencies(devDeps),
    );
  }

  /// Walks the project tree once, collecting per-extension file counts,
  /// top-level platform directory sizes, and files over the size threshold.
  Future<
    ({
      Map<String, int> fileStats,
      Map<String, int> structure,
      List<String> largeFiles,
    })
  >
  _walkProjectTree(String projectPath) async {
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

    return (fileStats: fileStats, structure: structure, largeFiles: largeFiles);
  }
}
