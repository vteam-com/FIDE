import 'dart:io';

import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:path/path.dart' as p;

/// Gathers project metrics: pubspec info and file and directory
/// statistics; `HealthChecker` runs the health checks.
///
/// Produces the [ProjectMetrics] persisted by `ProjectMetricsNotifier` and
/// rendered by the Info panel.
class ProjectAnalyzer {
  static final Set<String> _trackedTopLevelDirectories = {
    for (final platform in FlutterPlatform.values) platform.name,
    ProjectPaths.libFolder,
    ProjectPaths.testFolder,
  };

  final ProjectConfigReader _config;

  /// Creates an analyzer reading the project's pubspec with [_config].
  const ProjectAnalyzer(this._config);

  /// Analyzes the project at [projectPath].
  Future<ProjectMetrics> analyze(String projectPath) async {
    final pubspec = await _config.pubspec(projectPath);
    final tree = await _walkProjectTree(projectPath);

    return ProjectMetrics(
      name: pubspec?.name,
      version: pubspec?.version,
      description: pubspec?.description,
      dependencies: _describeDependencies(pubspec?.dependencies ?? const {}),
      devDependencies: _describeDependencies(
        pubspec?.devDependencies ?? const {},
      ),
      fileStats: tree.fileStats,
      directoryStructure: tree.structure,
    );
  }

  /// Maps each dependency name to its typed version.
  Map<String, DependencyVersion> _describeDependencies(
    Map<String, Object?> deps,
  ) {
    return deps.map(
      (name, value) => MapEntry(name, DependencyVersion.fromPubspec(value)),
    );
  }

  /// Walks the project tree once, collecting per-extension file counts
  /// and top-level platform directory sizes.
  Future<({Map<String, int> fileStats, Map<String, int> structure})>
  _walkProjectTree(String projectPath) async {
    final fileStats = <String, int>{};
    final structure = <String, int>{};

    await for (final entity in ProjectFiles.entities(projectPath)) {
      final relative = p.relative(entity.path, from: projectPath);
      if (entity is File) {
        final extension = FileTypeUtils.extensionOf(entity.path);
        fileStats[extension] = (fileStats[extension] ?? 0) + 1;
      } else if (entity is Directory) {
        final category = p.split(relative).first;
        if (_trackedTopLevelDirectories.contains(category)) {
          structure[category] = (structure[category] ?? 0) + 1;
        }
      }
    }

    return (fileStats: fileStats, structure: structure);
  }
}
