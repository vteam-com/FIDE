import 'dart:async';
import 'dart:io';

import 'package:fide/models/action_status.dart';
import 'package:fide/models/build_step_event.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notifier_state.dart';

const String _log = 'log';

void main() {
  late CommandRunner runner;
  late List<String> buildErrors;

  setUp(() {
    buildErrors = [];
    runner = CommandRunner(onBuildErrors: buildErrors.add);
  });

  tearDown(() => runner.dispose());

  /// Runs action [id] with [command] on [runner], or [on], reporting
  /// build errors.
  Future<bool> run(
    String id,
    Future<int> Function() command, {
    CommandRunner? on,
  }) => (on ?? runner).run(
    id,
    logKey: _log,
    startMessages: const ['start'],
    command: (_) => command(),
    successMessage: 'ok',
    failureMessage: (code) => 'failed $code',
    errorPrefix: 'error: ',
    reportsBuildErrors: true,
  );

  test('keeps the status and log of a run in the provider', () async {
    final exit = Completer<int>();
    final done = run('build', () => exit.future);

    expect(stateOf(runner).isRunning('build'), isTrue);

    exit.complete(1);
    expect(await done, isFalse);
    final runs = stateOf(runner);
    expect(runs.statusOf('build'), ActionStatus.error);
    expect(runs.logOf(_log).output, 'start\n');
    expect(runs.logOf(_log).errors, 'failed 1\n');
    expect(buildErrors, ['failed 1\n']);
  });

  test('stop kills the process and the run ends idle', () async {
    final done = runner.run(
      'run',
      logKey: _log,
      startMessages: const [],
      command: (output) async {
        final process = await Process.start('sleep', ['30']);
        output.onProcessStarted!(process);
        return process.exitCode;
      },
      successMessage: 'ok',
      failureMessage: (code) => 'failed $code',
      errorPrefix: 'error: ',
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    runner.stop('run');

    expect(await done, isFalse);
    final runs = stateOf(runner);
    expect(runs.statusOf('run'), ActionStatus.idle);
    expect(runs.logOf(_log).output, contains('Stopped'));
  });

  test('a project change ends every run and forgets its log', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final exit = Completer<int>();
    final done = run(
      'build',
      () => exit.future,
      on: container.read(commandRunnerProvider.notifier),
    );

    container.read(currentProjectPathProvider.notifier).state = '/other';
    exit.complete(0);
    await done;

    final runs = container.read(commandRunnerProvider);
    expect(runs.statusOf('build'), ActionStatus.idle);
    expect(runs.logOf(_log).hasOutput, isFalse);
  });

  test('turns live at the output marking the launch', () async {
    final exit = Completer<int>();
    late BuildOutput output;
    final done = runner.run(
      'run',
      logKey: _log,
      startMessages: const [],
      command: (o) {
        output = o;
        return exit.future;
      },
      successMessage: 'ok',
      failureMessage: (code) => 'failed $code',
      errorPrefix: 'error: ',
      isLive: (text) => text.contains('ready'),
    );
    ActionStatus status() => stateOf(runner).statusOf('run');

    output.onOutput('building');
    expect(status(), ActionStatus.running);
    output.onOutput('ready');
    expect(status(), ActionStatus.live);
    expect(stateOf(runner).isRunning('run'), isTrue);

    exit.complete(0);
    await done;
    expect(status(), ActionStatus.success);
  });

  test('narrates build steps and a failed step in the log', () async {
    await runner.run(
      'clean',
      logKey: _log,
      startMessages: const [],
      command: (output) async {
        output.onStep(
          const BuildStepEvent(
            BuildStep.flutterClean,
            BuildStepStatus.started,
            detail: 'clean',
          ),
        );
        throw const BuildException(BuildStep.pubGet, 'pub get', 1);
      },
      successMessage: 'ok',
      failureMessage: (code) => 'failed $code',
      errorPrefix: 'error: ',
    );

    final log = stateOf(runner).logOf(_log);
    expect(log.output, '🧹 Running flutter clean...\n');
    expect(log.errors, 'error: Flutter pub get failed with exit code 1\n');
  });

  group('BuildNarration', () {
    /// The log lines of [event].
    (String output, String errors) lines(BuildStepEvent event) {
      final log = OutputLog();
      BuildNarration.log(log, event);
      return (log.output.trim(), log.errors.trim());
    }

    test('words every step of a deep clean and a repair', () {
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podRepoUpdate,
            BuildStepStatus.started,
          ),
        ).$1,
        '📦 Updating CocoaPods repository...',
      );
      expect(
        lines(
          const BuildStepEvent(BuildStep.podRepoUpdate, BuildStepStatus.failed),
        ).$1,
        '⚠️ Pod repo update failed, continuing with pod install...',
      );
      expect(
        lines(
          const BuildStepEvent(BuildStep.podInstall, BuildStepStatus.started),
        ).$1,
        '🔧 Running pod install with repo update...',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podInstall,
            BuildStepStatus.failed,
            exitCode: 3,
          ),
        ).$1,
        '⚠️ Pod install failed with exit code 3, continuing with Flutter cleanup...\n'
        '🔄 CocoaPods issues will require manual resolution',
      );
      expect(
        lines(
          const BuildStepEvent(BuildStep.podInstall, BuildStepStatus.succeeded),
        ).$1,
        '✅ CocoaPods dependencies updated successfully',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.flutterBuild,
            BuildStepStatus.started,
            detail: 'build macos',
          ),
        ).$1,
        '🔨 Running flutter build macos...',
      );
      expect(
        lines(
          const BuildStepEvent(BuildStep.deepClean, BuildStepStatus.succeeded),
        ).$1,
        '✨ Deep clean and rebuild completed successfully!',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podRepoRepair,
            BuildStepStatus.needed,
            detail: 'stale',
          ),
        ).$1,
        '🛠️ CocoaPods repository error detected in output line: "stale"',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podRepoRepair,
            BuildStepStatus.started,
          ),
        ).$1,
        '🔧 Detected CocoaPods repository issue. Running pod repo update...',
      );
      expect(
        lines(
          const BuildStepEvent(BuildStep.podRepoRepair, BuildStepStatus.failed),
        ).$2,
        '❌ Failed to update CocoaPods repository',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podRepoRepair,
            BuildStepStatus.failed,
            detail: 'boom',
          ),
        ).$2,
        '❌ Error running pod repo update: boom',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.podRepoRepair,
            BuildStepStatus.succeeded,
          ),
        ).$1,
        '✅ CocoaPods repository updated successfully',
      );
      expect(
        lines(
          const BuildStepEvent(
            BuildStep.flutterBuild,
            BuildStepStatus.retrying,
          ),
        ).$1,
        '🔄 Retrying Flutter build...',
      );
      expect(
        lines(const BuildStepEvent(BuildStep.deepClean, BuildStepStatus.needed))
            .$1,
        'deepClean: needed',
      );
    });
  });
}
