import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/process_runner.dart';

part 'flutter_build_service.build_exception.dart';
part 'flutter_build_service.build_output.dart';

/// Runs Flutter build commands, streaming their output.
///
/// Holds no UI state and no wording: callers render whatever arrives
/// through [BuildOutput] and decide how to present success or failure. A
/// failed [clean] throws a [BuildException].
class FlutterBuildService {
  /// Line `flutter run` prints once the app has launched.
  static const String _appLaunchedMarker = 'Flutter run key commands';

  final ProcessRunner _runner;

  /// Creates a build service that launches commands through [_runner].
  const FlutterBuildService(this._runner);

  /// Builds [platform] in [projectPath] as [target], one of its
  /// [FlutterPlatform.buildTargets] (the default one when null), and
  /// returns the exit code.
  Future<int> build(
    String projectPath,
    FlutterPlatform platform,
    BuildOutput output, {
    String? target,
  }) {
    return _stream(
      'flutter',
      platform.buildArguments(target),
      output,
      workingDirectory: projectPath,
    );
  }

  /// Runs `flutter clean`.
  ///
  /// Throws a [BuildException] when the clean does not succeed, or refuses
  /// the running app's own project ([ProjectPaths.ensureCleanable]).
  Future<void> clean(String projectPath, BuildOutput output) async {
    ProjectPaths(projectPath).ensureCleanable(Platform.resolvedExecutable);
    const arguments = ['clean'];
    final exitCode = await _stream(
      'flutter',
      arguments,
      output,
      workingDirectory: projectPath,
    );
    if (exitCode != 0) {
      throw BuildException(arguments.join(' '), exitCode);
    }
  }

  /// Whether [output] of [run] shows the app has launched: `flutter run`
  /// lists its key commands once the app is up.
  static bool isAppLaunched(String output) =>
      output.contains(_appLaunchedMarker);

  /// Runs the app on [device] in debug or release mode; completes with the
  /// exit code when the app stops.
  Future<int> run(
    String projectPath,
    String device,
    BuildOutput output, {
    required bool isDebug,
  }) {
    return _stream(
      'flutter',
      ['run', if (!isDebug) '--release', '-d', device],
      output,
      workingDirectory: projectPath,
    );
  }

  /// Runs `flutter test` in [projectPath] on [paths] (every test when
  /// empty), collecting coverage when [coverage] is set; returns the exit
  /// code.
  Future<int> test(
    String projectPath,
    BuildOutput output, {
    List<String> paths = const [],
    bool coverage = false,
  }) {
    return _stream(
      'flutter',
      ['test', if (coverage) '--coverage', ...paths],
      output,
      workingDirectory: projectPath,
    );
  }

  /// Streams a command's output to [output].
  Future<int> _stream(
    String executable,
    List<String> arguments,
    BuildOutput output, {
    String? workingDirectory,
  }) {
    return _runner.stream(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      onStdout: output.onOutput,
      onStderr: output.onError,
      onStarted: output.onProcessStarted,
    );
  }
}
