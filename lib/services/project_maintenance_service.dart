import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/outdated_package.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pub_outdated.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/pubspec_upgrader.dart';

part 'project_maintenance_service.maintenance_exception.dart';
part 'project_maintenance_service.version_conflict_exception.dart';

/// Dependency and cleanup chores for a Flutter project: `pub outdated`,
/// upgrading pubspec constraints, and full artifact cleanup.
///
/// Chores that can't finish throw a [MaintenanceException]; an upgrade pub
/// can't resolve throws its [VersionConflictException].
class ProjectMaintenanceService {
  final ProcessRunner _runner;

  /// Creates a maintenance service that launches commands through [_runner].
  const ProjectMaintenanceService(this._runner);

  /// Cleans Flutter, removes build artifacts, repairs the pub cache, and
  /// refreshes Gradle and CocoaPods where those platforms exist. Refuses the
  /// running app's own project ([ProjectPaths.ensureCleanable]).
  Future<void> fullCleanup(String projectPath) async {
    ProjectPaths(projectPath).ensureCleanable(Platform.resolvedExecutable);
    await _runChecked('flutter', ['clean'], workingDirectory: projectPath);

    final buildDir = Directory(ProjectPaths(projectPath).buildDir);
    if (buildDir.existsSync()) {
      await buildDir.delete(recursive: true);
    }

    await _runChecked('flutter', ['pub', 'cache', 'repair']);

    if (Directory('$projectPath/android').existsSync()) {
      await _runChecked('./gradlew', [
        'clean',
      ], workingDirectory: '$projectPath/android');
    }

    if (Platform.isMacOS) {
      for (final platform in FlutterPlatform.values.where(
        (platform) => platform.usesCocoaPods,
      )) {
        final platformPath = '$projectPath/${platform.name}';
        if (Directory(platformPath).existsSync()) {
          await _runChecked('pod', [
            'install',
            '--repo-update',
          ], workingDirectory: platformPath);
        }
      }
    }
  }

  /// Runs `flutter pub outdated` and returns the table it printed, as text
  /// and parsed into one [OutdatedPackage] per package name.
  ///
  /// Throws a [MaintenanceException] with the command's stderr when it
  /// fails.
  Future<({String output, Map<String, OutdatedPackage> packages})>
  outdatedReport(String projectPath) async {
    final result = await _runner.run('flutter', [
      'pub',
      'outdated',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      throw MaintenanceException('${result.stderr}');
    }
    final output = result.stdout.toString();
    return (output: output, packages: OutdatedPackage.parseTable(output));
  }

  /// Raises direct and dev dependency constraints in pubspec.yaml to their
  /// latest resolvable versions, then runs `flutter pub get`.
  ///
  /// Returns the packages raised; empty when everything was already
  /// current. Throws a [MaintenanceException] on command or parse
  /// failure, a [VersionConflictException] when pub can't resolve the
  /// result.
  Future<List<PubOutdatedPackage>> upgradeToResolvable(
    String projectPath,
  ) async {
    final result = await _runner.run('flutter', [
      'pub',
      'outdated',
      '--json',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      throw MaintenanceException('Failed to check outdated: ${result.stderr}');
    }

    final PubOutdated outdated;
    try {
      outdated = PubOutdated.parse(result.stdout.toString());
    } on FormatException catch (e) {
      throw MaintenanceException(
        'Invalid JSON response from flutter pub outdated: ${e.message}',
      );
    }

    final pubspecFile = File(ProjectPaths(projectPath).pubspec);
    if (!pubspecFile.existsSync()) {
      throw const MaintenanceException('pubspec.yaml not found');
    }
    final upgrade = PubspecUpgrader.upgrade(
      await pubspecFile.readAsString(),
      outdated,
    );
    if (upgrade.upgraded.isNotEmpty) {
      await pubspecFile.writeAsString(upgrade.yaml);
    }

    await _runChecked('flutter', ['pub', 'get'], workingDirectory: projectPath);
    return upgrade.upgraded;
  }

  /// Runs a command to completion.
  ///
  /// Throws a [VersionConflictException] when it fails on pub's version
  /// solving, else a [MaintenanceException] with its exit code and stderr.
  Future<void> _runChecked(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final result = await _runner.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    if (result.exitCode == 0) return;
    final error = '${result.stderr}';
    if (VersionConflictException.isConflict(error)) {
      throw VersionConflictException.fromPubError(error);
    }
    throw MaintenanceException(
      'Command failed with exit code ${result.exitCode}\n$error',
    );
  }
}
