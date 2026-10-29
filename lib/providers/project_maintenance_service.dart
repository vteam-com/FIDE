import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/outdated_package.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Dependency and cleanup chores for a Flutter project: `pub outdated`,
/// upgrading pubspec constraints, and full artifact cleanup.
class ProjectMaintenanceService {
  final ProcessRunner _runner;

  /// Creates a maintenance service that launches commands through [_runner].
  const ProjectMaintenanceService([this._runner = const ProcessRunner()]);

  /// Pub's marker for a failed resolution.
  static const String versionSolvingFailed = 'version solving failed';

  /// Summarizes pub's version-solving [error]: the first explanatory line
  /// after the failure marker, and the package named in "X depends on both
  /// `<package>`" when pub reports one.
  static ({String summary, String? package}) parseVersionConflict(
    String error,
  ) {
    final lines = error.split('\n').map((line) => line.trim()).toList();
    final failureLine = lines.indexWhere(
      (line) => line.contains('$versionSolvingFailed.'),
    );
    final summary = failureLine == -1
        ? null
        : lines
              .skip(failureLine + 1)
              .where(
                (line) => line.isNotEmpty && !line.startsWith('* Consider'),
              )
              .firstOrNull;
    final package = RegExp(r'\S+ depends on both (\w+) ').firstMatch(error);
    return (
      summary: summary ?? 'Dependency conflict detected',
      package: package?.group(1),
    );
  }

  /// Parses the table printed by `flutter pub outdated` into
  /// one [OutdatedPackage] per package name.
  static Map<String, OutdatedPackage> parseOutdated(String output) {
    final outdated = <String, OutdatedPackage>{};

    for (String line in output.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= AppMetric.outdatedMinColumns &&
          parts[0] != 'Package' &&
          parts[0] != '---') {
        outdated[parts[0]] = OutdatedPackage(
          current: parts[1],
          upgradable: parts[AppMetric.outdatedUpgradableColIndex],
          resolvable: parts[AppMetric.outdatedResolvableColIndex],
          latest: parts.length > AppMetric.outdatedLatestColIndex
              ? parts[AppMetric.outdatedLatestColIndex]
              : '',
        );
      }
    }

    return outdated;
  }

  /// Cleans Flutter, removes build artifacts, repairs the pub cache, and
  /// refreshes Gradle and CocoaPods where those platforms exist. Refuses the
  /// running app's own project ([ProjectPaths.ensureCleanable]).
  Future<void> fullCleanup(String projectPath) async {
    ProjectPaths(projectPath).ensureCleanable();
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

  /// Runs `flutter pub outdated` and returns its table output.
  ///
  /// Throws the command's stderr when it fails.
  Future<String> outdatedReport(String projectPath) async {
    final result = await _runner.run('flutter', [
      'pub',
      'outdated',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      throw '${result.stderr}';
    }
    return result.stdout as String;
  }

  /// Raises direct and dev dependency constraints in pubspec.yaml to their
  /// latest resolvable versions, then runs `flutter pub get`.
  ///
  /// Returns one `name: old → new` line per updated package; empty when
  /// everything was already current. Throws on command or parse failure,
  /// including pub's version-solving output.
  Future<List<String>> upgradeToResolvable(String projectPath) async {
    final result = await _runner.run('flutter', [
      'pub',
      'outdated',
      '--json',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      throw 'Failed to check outdated: ${result.stderr}';
    }

    final outdatedJson = result.stdout is String
        ? result.stdout as String
        : utf8.decode(result.stdout as List<int>);
    final dynamic outdatedData = json.decode(outdatedJson);
    if (outdatedData is! Map<String, dynamic>) {
      throw 'Invalid JSON response from flutter pub outdated: expected Map, got ${outdatedData.runtimeType}';
    }

    // Format: {"packages": [{"package", "kind", "current": {...}, "resolvable": {...}}]}
    final packages = outdatedData['packages'];
    if (packages is! List) {
      throw 'Expected packages to be an array, got ${packages?.runtimeType}';
    }

    final pubspecFile = File(ProjectPaths(projectPath).pubspec);
    if (!pubspecFile.existsSync()) {
      throw 'pubspec.yaml not found';
    }
    final yamlEditor = YamlEditor(await pubspecFile.readAsString());

    final updatedPackages = <String>[];
    for (final pkg in packages) {
      if (pkg is! Map<String, dynamic>) continue;

      final packageName = pkg['package'] as String?;
      if (packageName == null) continue;

      // Only update direct and dev dependencies
      final kind = pkg['kind'] as String?;
      if (kind != 'direct' && kind != 'dev') continue;

      final resolvable = pkg['resolvable'];
      if (resolvable is! Map<String, dynamic>) continue;
      final newVersion = resolvable['version']?.toString();
      if (newVersion == null || newVersion.isEmpty) continue;

      final current = pkg['current'];
      final currentVersion = current is Map<String, dynamic>
          ? current['version']?.toString()
          : null;
      if (currentVersion == null || currentVersion == newVersion) continue;

      final pathToUpdate = [
        kind == 'direct' ? 'dependencies' : 'dev_dependencies',
        packageName,
      ];
      try {
        // Parse at the path to make sure it exists
        yamlEditor.parseAt(pathToUpdate).value;
        yamlEditor.update(pathToUpdate, newVersion);
        updatedPackages.add('$packageName: $currentVersion → $newVersion');
      } catch (_) {
        // Continue to next package if this one fails
        continue;
      }
    }

    if (updatedPackages.isNotEmpty) {
      await pubspecFile.writeAsString(yamlEditor.toString());
    }

    await _runChecked('flutter', ['pub', 'get'], workingDirectory: projectPath);
    return updatedPackages;
  }

  /// Runs a command to completion, throwing its exit code and stderr on
  /// failure so callers can inspect messages like pub's version solving.
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
    if (result.exitCode != 0) {
      throw 'Command failed with exit code ${result.exitCode}\n${result.stderr}';
    }
  }
}
