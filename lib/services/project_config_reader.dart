import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:path/path.dart' as p;

/// Reads how a project is set up from its files: its `pubspec.yaml`, its
/// `l10n.yaml` and its platform folders, leaving the parsing to the models.
class ProjectConfigReader {
  /// Creates a reader of the files on disk.
  const ProjectConfigReader();

  /// The `flutter gen-l10n` settings of the project at [projectPath]; the
  /// defaults when it has no `l10n.yaml`.
  Future<L10nConfig> l10nConfig(String projectPath) async {
    final content = await _readIfExists(
      p.join(projectPath, L10nConfig.fileName),
    );
    return content == null ? const L10nConfig() : L10nConfig.parse(content);
  }

  /// The package name of the project at [projectPath]; null without a
  /// pubspec or a name in it.
  Future<String?> packageName(String projectPath) async =>
      (await pubspec(projectPath))?.name;

  /// The platforms that have a folder in the project at [projectPath].
  Set<FlutterPlatform> platforms(String projectPath) => {
    for (final platform in FlutterPlatform.values)
      if (Directory(p.join(projectPath, platform.name)).existsSync()) platform,
  };

  /// The pubspec of the project at [projectPath]; null when the project
  /// has none.
  Future<Pubspec?> pubspec(String projectPath) async {
    final content = await _readIfExists(ProjectPaths(projectPath).pubspec);
    return content == null ? null : Pubspec.parse(content);
  }

  /// The text of the file at [path]; null when there is none.
  static Future<String?> _readIfExists(String path) async {
    final file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }
}
