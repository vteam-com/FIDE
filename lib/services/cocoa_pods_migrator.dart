import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/cocoa_pods_migration.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:path/path.dart' as p;

/// Moves a project's iOS and macOS apps from CocoaPods to Swift Package
/// Manager: tells what still needs CocoaPods, from fCheck's package
/// platform warnings and the Podfiles, and removes CocoaPods once nothing
/// does.
class CocoaPodsMigrator {
  /// Files and folders CocoaPods leaves in a platform folder.
  static const List<String> _podArtifacts = [
    CocoaPodsMigration.podfileName,
    'Podfile.lock',
    'Pods',
    '.symlinks',
  ];

  /// Folder of each Apple platform holding its `*.xcconfig` files.
  static const String _xcconfigFolder = 'Flutter';

  /// Extension of the Xcode configuration files.
  static const String _xcconfigExtension = '.xcconfig';

  /// An `#include` line of an xcconfig file reading a CocoaPods file.
  static final RegExp _podsInclude = RegExp(
    r'^\s*#include\??\s+"[^"]*Pods[^"]*"\s*$',
  );

  final ProcessRunner _runner;

  final ProjectConfigReader _config;

  /// Creates a migrator running `pod` through [_runner] and reading the
  /// project's pubspec with [_config].
  const CocoaPodsMigrator(
    this._runner, [
    this._config = const ProjectConfigReader(),
  ]);

  /// Where the project at [projectPath] stands, reading its pubspec, the
  /// Podfiles of its Apple [platforms] and fCheck's [warnings].
  Future<CocoaPodsMigration> inspect(
    String projectPath,
    Set<FlutterPlatform> platforms,
    List<fcheck.PackagePlatformWarning> warnings,
  ) async {
    final applePlatforms = platforms.where((platform) => platform.isApple);
    if (applePlatforms.isEmpty) return CocoaPodsMigration.none;
    final pubspec = await _config.pubspec(projectPath) ?? Pubspec.parse('');
    final podfiles = {
      for (final platform in applePlatforms)
        if (File(_podfile(projectPath, platform)) case final podfile
            when podfile.existsSync())
          platform: podfile,
    };
    return CocoaPodsMigration(
      projectPath: projectPath,
      podPlatforms: podfiles.keys.toSet(),
      blockers: [
        for (final warning in warnings)
          CocoaPodsBlocker(
            packageName: warning.packageName,
            version: warning.version,
            introducedBy: warning.introducedBy,
            line:
                pubspec.dependencyLines[warning.introducedBy ??
                    warning.packageName] ??
                1,
          ),
      ],
      handAddedPods: [
        for (final podfile in podfiles.values)
          ...CocoaPodsMigration.handAddedPodsIn(
            podfile.path,
            podfile.readAsStringSync(),
          ),
      ],
      swiftPackageManagerOffLine: pubspec.disablesSwiftPackageManager
          ? pubspec.swiftPackageManagerLine ?? 1
          : null,
    );
  }

  /// Removes CocoaPods from each platform of [migration] that has it:
  /// `pod deintegrate`, then its Podfile, lock, `Pods/` and `.symlinks/`,
  /// then the CocoaPods `#include` lines of its xcconfig files, following
  /// Flutter's guide. Returns the files it rewrote.
  ///
  /// Throws a [MaintenanceException] when `pod deintegrate` fails, before
  /// touching that platform's files.
  Future<List<String>> remove(CocoaPodsMigration migration) async {
    final changed = <String>[];
    for (final platform in migration.podPlatforms) {
      final folder = ProjectPaths(migration.projectPath).platformDir(platform);
      await _runner.runChecked(
        'pod',
        ['deintegrate'],
        workingDirectory: folder,
        runInShell: true,
        error: (result) => MaintenanceException(
          'pod deintegrate failed for ${platform.displayName}: '
          '${result.stderr}',
        ),
      );
      for (final name in _podArtifacts) {
        final path = p.join(folder, name);
        final type = FileSystemEntity.typeSync(path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else if (type != FileSystemEntityType.notFound) {
          await File(path).delete();
        }
      }
      changed.addAll(await _dropPodsIncludes(p.join(folder, _xcconfigFolder)));
    }
    return changed;
  }

  /// [xcconfig] without its CocoaPods `#include` lines.
  static String withoutPodsIncludes(String xcconfig) => xcconfig
      .split('\n')
      .where((line) => !_podsInclude.hasMatch(line))
      .join('\n');

  /// Drops the CocoaPods `#include` lines of the xcconfig files in
  /// [folder]; returns the files it rewrote.
  Future<List<String>> _dropPodsIncludes(String folder) async {
    final directory = Directory(folder);
    if (!directory.existsSync()) return const [];
    final changed = <String>[];
    await for (final entity in directory.list()) {
      if (entity is! File || p.extension(entity.path) != _xcconfigExtension) {
        continue;
      }
      final content = await entity.readAsString();
      final cleaned = withoutPodsIncludes(content);
      if (cleaned != content) {
        await entity.writeAsString(cleaned);
        changed.add(entity.path);
      }
    }
    return changed;
  }

  /// The Podfile of [platform] in the project at [projectPath].
  static String _podfile(String projectPath, FlutterPlatform platform) =>
      p.join(
        ProjectPaths(projectPath).platformDir(platform),
        CocoaPodsMigration.podfileName,
      );
}
