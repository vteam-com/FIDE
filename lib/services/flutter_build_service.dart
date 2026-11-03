import 'dart:io';

import 'package:fide/models/build_step_event.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/process_runner.dart';

part 'flutter_build_service.build_exception.dart';
part 'flutter_build_service.build_output.dart';

/// Runs Flutter and CocoaPods build commands, streaming their output.
///
/// Holds no UI state and no wording: callers render whatever arrives
/// through [BuildOutput], its [BuildStepEvent]s included, and decide how
/// to present success or failure. A failed `flutter` step of [clean] or
/// [deepClean] throws a [BuildException].
class FlutterBuildService {
  /// Line `flutter run` prints once the app has launched.
  static const String _appLaunchedMarker = 'Flutter run key commands';
  static const String _podOutputPrefix = 'POD: ';

  /// `pod install --repo-update`.
  static const List<String> _podInstallArguments = ['install', '--repo-update'];

  final ProcessRunner _runner;

  /// Creates a build service that launches commands through [_runner].
  const FlutterBuildService(this._runner);

  /// Returns true when [text] reports an out-of-date CocoaPods specs repo,
  /// which `pod repo update` fixes.
  static bool isCocoaPodsRepoError(String text) {
    return text.contains("CocoaPods's specs repository is too out-of-date") ||
        text.contains('out-of-date source repos') ||
        (text.contains('pod repo update') && text.contains('You have either'));
  }

  /// Builds [platform] in [projectPath] as [target], one of its
  /// [FlutterPlatform.buildTargets] (the default one when null), and
  /// returns the exit code.
  ///
  /// Builds of CocoaPods platforms that fail on a stale CocoaPods repo
  /// update it and retry once.
  Future<int> build(
    String projectPath,
    FlutterPlatform platform,
    BuildOutput output, {
    String? target,
  }) {
    return _runRepairingPods(
      BuildStep.flutterBuild,
      platform.buildArguments(target),
      output,
      workingDirectory: projectPath,
      canRepair: platform.usesCocoaPods,
    );
  }

  /// Runs `flutter clean`, repairing a stale CocoaPods repo once if needed.
  ///
  /// Throws a [BuildException] when the clean does not succeed, or refuses
  /// the running app's own project ([ProjectPaths.ensureCleanable]).
  Future<void> clean(String projectPath, BuildOutput output) async {
    ProjectPaths(projectPath).ensureCleanable(Platform.resolvedExecutable);
    const arguments = ['clean'];
    final exitCode = await _runRepairingPods(
      BuildStep.flutterClean,
      arguments,
      output,
      workingDirectory: projectPath,
    );
    if (exitCode != 0) {
      throw BuildException(
        BuildStep.flutterClean,
        arguments.join(' '),
        exitCode,
      );
    }
  }

  /// Refreshes the CocoaPods of [platform], one that
  /// [FlutterPlatform.usesCocoaPods], then cleans, fetches packages and
  /// rebuilds it. Refuses the running app's own project
  /// ([ProjectPaths.ensureCleanable]).
  ///
  /// CocoaPods failures are reported but tolerated; a failed Flutter step
  /// throws its [BuildException].
  Future<void> deepClean(
    String projectPath,
    FlutterPlatform platform,
    BuildOutput output,
  ) async {
    ProjectPaths(projectPath).ensureCleanable(Platform.resolvedExecutable);
    final podsPath = '$projectPath/${platform.name}';

    output.onStep(
      const BuildStepEvent(BuildStep.podRepoUpdate, BuildStepStatus.started),
    );
    if (!await _updatePodRepo(output, workingDirectory: podsPath)) {
      output.onStep(
        const BuildStepEvent(BuildStep.podRepoUpdate, BuildStepStatus.failed),
      );
    }

    output.onStep(
      const BuildStepEvent(BuildStep.podInstall, BuildStepStatus.started),
    );
    final podExitCode = await _stream(
      'pod',
      _podInstallArguments,
      output,
      workingDirectory: podsPath,
      prefix: _podOutputPrefix,
    );
    output.onStep(
      podExitCode == 0
          ? const BuildStepEvent(
              BuildStep.podInstall,
              BuildStepStatus.succeeded,
            )
          : BuildStepEvent(
              BuildStep.podInstall,
              BuildStepStatus.failed,
              exitCode: podExitCode,
            ),
    );

    await _runFlutterStep(
      BuildStep.flutterClean,
      ['clean'],
      projectPath,
      output,
    );
    await _runFlutterStep(
      BuildStep.pubGet,
      ['pub', 'get'],
      projectPath,
      output,
    );
    await _runFlutterStep(
      BuildStep.flutterBuild,
      platform.buildArguments(),
      projectPath,
      output,
    );

    output.onStep(
      const BuildStepEvent(BuildStep.deepClean, BuildStepStatus.succeeded),
    );
  }

  /// Runs `pod install --repo-update` in [directory] and returns the exit code.
  Future<int> podInstall(String directory, BuildOutput output) {
    return _stream(
      'pod',
      _podInstallArguments,
      output,
      workingDirectory: directory,
    );
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

  /// Runs one `flutter` [step] with [arguments], reporting its start.
  ///
  /// Throws a [BuildException] when it exits non-zero.
  Future<void> _runFlutterStep(
    BuildStep step,
    List<String> arguments,
    String projectPath,
    BuildOutput output,
  ) async {
    final joined = arguments.join(' ');
    output.onStep(
      BuildStepEvent(step, BuildStepStatus.started, detail: joined),
    );
    final exitCode = await _stream(
      'flutter',
      arguments,
      output,
      workingDirectory: projectPath,
    );
    if (exitCode != 0) {
      throw BuildException(step, joined, exitCode);
    }
  }

  /// Runs `flutter` [arguments] as [step] and, when it fails on a stale
  /// CocoaPods repo and [canRepair] is set, updates the repo and retries
  /// exactly once.
  Future<int> _runRepairingPods(
    BuildStep step,
    List<String> arguments,
    BuildOutput output, {
    required String workingDirectory,
    bool canRepair = true,
  }) async {
    var podRepoOutdated = false;
    final exitCode = await _runner.stream(
      'flutter',
      arguments,
      workingDirectory: workingDirectory,
      onStdout: output.onOutput,
      onStderr: (text) {
        if (isCocoaPodsRepoError(text)) {
          podRepoOutdated = true;
          output.onStep(
            BuildStepEvent(
              BuildStep.podRepoRepair,
              BuildStepStatus.needed,
              detail: text,
            ),
          );
        }
        output.onError(text);
      },
      onStarted: output.onProcessStarted,
    );
    if (exitCode == 0 || !podRepoOutdated || !canRepair) {
      return exitCode;
    }

    output.onStep(
      const BuildStepEvent(BuildStep.podRepoRepair, BuildStepStatus.started),
    );
    try {
      if (!await _updatePodRepo(output)) {
        output.onStep(
          const BuildStepEvent(BuildStep.podRepoRepair, BuildStepStatus.failed),
        );
        return exitCode;
      }
    } catch (e) {
      output.onStep(
        BuildStepEvent(
          BuildStep.podRepoRepair,
          BuildStepStatus.failed,
          detail: '$e',
        ),
      );
      return exitCode;
    }

    output.onStep(
      const BuildStepEvent(BuildStep.podRepoRepair, BuildStepStatus.succeeded),
    );
    output.onStep(BuildStepEvent(step, BuildStepStatus.retrying));
    output.onResetErrors();
    return _runRepairingPods(
      step,
      arguments,
      output,
      workingDirectory: workingDirectory,
      canRepair: false,
    );
  }

  /// Streams a command's output to [output], optionally tagging each line.
  Future<int> _stream(
    String executable,
    List<String> arguments,
    BuildOutput output, {
    String? workingDirectory,
    String prefix = '',
  }) {
    return _runner.stream(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      onStdout: (text) => output.onOutput('$prefix$text'),
      onStderr: (text) => output.onError('$prefix$text'),
      onStarted: output.onProcessStarted,
    );
  }

  /// Runs `pod repo update`; returns true when it succeeds.
  Future<bool> _updatePodRepo(
    BuildOutput output, {
    String? workingDirectory,
  }) async {
    final exitCode = await _stream(
      'pod',
      ['repo', 'update'],
      output,
      workingDirectory: workingDirectory,
      prefix: _podOutputPrefix,
    );
    return exitCode == 0;
  }
}
