import 'dart:async';
import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/flutter_app_session.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';

part 'flutter_build_service.build_exception.dart';
part 'flutter_build_service.build_output.dart';

/// Runs Flutter build commands, streaming their output.
///
/// Holds no UI state and no wording: callers render whatever arrives
/// through [BuildOutput] and decide how to present success or failure. A
/// failed [clean] throws a [BuildException].
class FlutterBuildService {
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
      FlutterSdk.executable,
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
      FlutterSdk.executable,
      arguments,
      output,
      workingDirectory: projectPath,
    );
    if (exitCode != 0) {
      throw BuildException(arguments.join(' '), exitCode);
    }
  }

  /// Runs the app on [device] in debug or release mode as a
  /// [FlutterAppSession], given to [BuildOutput.onAppStarted] once the app
  /// runs, to hot reload and stop it; completes with the exit code when
  /// the app stops.
  Future<int> run(
    String projectPath,
    String device,
    BuildOutput output, {
    required bool isDebug,
  }) async {
    final session = FlutterAppSession(
      runner: _runner,
      projectPath: projectPath,
      arguments: [if (!isDebug) '--release', '-d', device],
      onOutput: output.onOutput,
      onError: output.onError,
    );
    output.onProcessStarted?.call(await session.launch());
    unawaited(
      session.started.then<void>(
        (_) => output.onAppStarted?.call(session),
        // The exit code tells a failed start
        onError: (Object _) {},
      ),
    );
    return session.exitCode;
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
      FlutterSdk.executable,
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
