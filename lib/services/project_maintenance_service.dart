import 'dart:io';

import 'package:fide/models/outdated_package.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pub_outdated.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/pubspec_upgrader.dart';

part 'project_maintenance_service.maintenance_exception.dart';
part 'project_maintenance_service.version_conflict_exception.dart';

/// Dependency chores for a Flutter project: `pub outdated` and upgrading
/// pubspec constraints.
///
/// Chores that can't finish throw a [MaintenanceException]; an upgrade pub
/// can't resolve throws its [VersionConflictException].
class ProjectMaintenanceService {
  final ProcessRunner _runner;

  /// Creates a maintenance service that launches commands through [_runner].
  const ProjectMaintenanceService(this._runner);

  /// Runs `flutter pub outdated` and returns the table it printed, as text
  /// and parsed into one [OutdatedPackage] per package name.
  ///
  /// Throws a [MaintenanceException] with the command's stderr when it
  /// fails.
  Future<({String output, Map<String, OutdatedPackage> packages})>
  outdatedReport(String projectPath) async {
    final result = await _runner.runChecked(
      FlutterSdk.executable,
      ['pub', 'outdated'],
      workingDirectory: projectPath,
      error: (result) => MaintenanceException('${result.stderr}'),
    );
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
    final result = await _runner.runChecked(
      FlutterSdk.executable,
      ['pub', 'outdated', '--json'],
      workingDirectory: projectPath,
      error: (result) =>
          MaintenanceException('Failed to check outdated: ${result.stderr}'),
    );

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

    await _runChecked(FlutterSdk.executable, [
      'pub',
      'get',
    ], workingDirectory: projectPath);
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
    await _runner.runChecked(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
      error: (result) {
        final error = '${result.stderr}';
        return VersionConflictException.isConflict(error)
            ? VersionConflictException.fromPubError(error)
            : MaintenanceException(
                'Command failed with exit code ${result.exitCode}\n$error',
              );
      },
    );
  }
}
