import 'dart:io';

import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/process_runner.dart';

part 'flutter_build_service.build_output.dart';

/// Runs Flutter and CocoaPods build commands, streaming their output.
///
/// Holds no UI state: callers render whatever arrives through [BuildOutput]
/// and decide how to present success or failure.
class FlutterBuildService {
  static const String _macosTarget = 'macos';
  static const String _podOutputPrefix = 'POD: ';
  static const String _webTarget = 'web';

  final ProcessRunner _runner;

  /// Creates a build service that launches commands through [_runner].
  const FlutterBuildService([this._runner = const ProcessRunner()]);

  /// Returns true when [text] reports an out-of-date CocoaPods specs repo,
  /// which `pod repo update` fixes.
  static bool isCocoaPodsRepoError(String text) {
    return text.contains("CocoaPods's specs repository is too out-of-date") ||
        text.contains('out-of-date source repos') ||
        (text.contains('pod repo update') && text.contains('You have either'));
  }

  /// Builds [target] in [projectPath] and returns the exit code.
  ///
  /// macOS builds that fail on a stale CocoaPods repo update it and retry once.
  Future<int> build(String projectPath, String target, BuildOutput output) {
    return _runRepairingPods(
      'flutter',
      ['build', target, if (target == _webTarget) '--no-wasm-dry-run'],
      output,
      workingDirectory: projectPath,
      retryLabel: 'Flutter build',
      canRepair: target == _macosTarget,
    );
  }

  /// Runs `flutter clean`, repairing a stale CocoaPods repo once if needed.
  ///
  /// Throws a message describing the failure when the clean does not succeed,
  /// or when the project is the running app ([ProjectPaths.ensureCleanable]).
  Future<void> clean(String projectPath, BuildOutput output) async {
    ProjectPaths(projectPath).ensureCleanable();
    final exitCode = await _runRepairingPods(
      'flutter',
      ['clean'],
      output,
      workingDirectory: projectPath,
      retryLabel: 'Flutter clean',
    );
    if (exitCode != 0) {
      throw 'Flutter clean failed with exit code $exitCode';
    }
  }

  /// Refreshes CocoaPods, then cleans, fetches packages and rebuilds macOS.
  /// Refuses the running app's own project ([ProjectPaths.ensureCleanable]).
  ///
  /// CocoaPods failures are reported but tolerated; Flutter step failures
  /// throw a message naming the failed step.
  Future<void> deepCleanMacOS(String projectPath, BuildOutput output) async {
    ProjectPaths(projectPath).ensureCleanable();
    final macOSPath = '$projectPath/macos';

    output.onOutput('📦 Updating CocoaPods repository...');
    if (!await _updatePodRepo(output, workingDirectory: macOSPath)) {
      output.onOutput(
        '⚠️ Pod repo update failed, continuing with pod install...',
      );
    }

    output.onOutput('🔧 Running pod install with repo update...');
    final podExitCode = await _stream(
      'pod',
      ['install', '--repo-update'],
      output,
      workingDirectory: macOSPath,
      prefix: _podOutputPrefix,
    );
    if (podExitCode != 0) {
      output.onOutput(
        '⚠️ Pod install failed with exit code $podExitCode, continuing with Flutter cleanup...',
      );
      output.onOutput('🔄 CocoaPods issues will require manual resolution');
    } else {
      output.onOutput('✅ CocoaPods dependencies updated successfully');
    }

    output.onOutput('🧹 Running flutter clean...');
    await _runFlutterStep(['clean'], projectPath, output);

    output.onOutput('📦 Running flutter pub get...');
    await _runFlutterStep(['pub', 'get'], projectPath, output);

    output.onOutput('🔨 Running flutter build macos...');
    await _runFlutterStep(['build', _macosTarget], projectPath, output);

    output.onOutput('✨ Deep clean and rebuild completed successfully!');
  }

  /// Runs `pod install --repo-update` in [directory] and returns the exit code.
  Future<int> podInstall(String directory, BuildOutput output) {
    return _stream(
      'pod',
      ['install', '--repo-update'],
      output,
      workingDirectory: directory,
    );
  }

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

  /// Runs one `flutter` step, throwing when it exits non-zero.
  Future<void> _runFlutterStep(
    List<String> arguments,
    String projectPath,
    BuildOutput output,
  ) async {
    final exitCode = await _stream(
      'flutter',
      arguments,
      output,
      workingDirectory: projectPath,
    );
    if (exitCode != 0) {
      throw 'Flutter ${arguments.join(' ')} failed with exit code $exitCode';
    }
  }

  /// Runs a command and, when it fails on a stale CocoaPods repo and
  /// [canRepair] is set, updates the repo and retries exactly once.
  Future<int> _runRepairingPods(
    String executable,
    List<String> arguments,
    BuildOutput output, {
    required String workingDirectory,
    required String retryLabel,
    bool canRepair = true,
  }) async {
    var podRepoOutdated = false;
    final exitCode = await _runner.stream(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      onStdout: output.onOutput,
      onStderr: (text) {
        if (isCocoaPodsRepoError(text)) {
          podRepoOutdated = true;
          output.onOutput(
            '🛠️ CocoaPods repository error detected in output line: "$text"',
          );
        }
        output.onError(text);
      },
      onStarted: output.onProcessStarted,
    );
    if (exitCode == 0 || !podRepoOutdated || !canRepair) {
      return exitCode;
    }

    output.onOutput(
      '🔧 Detected CocoaPods repository issue. Running pod repo update...',
    );
    try {
      if (!await _updatePodRepo(output)) {
        output.onError('❌ Failed to update CocoaPods repository');
        return exitCode;
      }
    } catch (e) {
      output.onError('❌ Error running pod repo update: $e');
      return exitCode;
    }

    output.onOutput('✅ CocoaPods repository updated successfully');
    output.onOutput('🔄 Retrying $retryLabel...');
    output.onResetErrors();
    return _runRepairingPods(
      executable,
      arguments,
      output,
      workingDirectory: workingDirectory,
      retryLabel: retryLabel,
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
