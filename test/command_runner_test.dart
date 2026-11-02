import 'dart:async';
import 'dart:io';

import 'package:fide/models/action_status.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _log = 'log';

void main() {
  late ProviderContainer container;
  late CommandRunner runner;

  setUp(() {
    container = ProviderContainer();
    runner = container.read(commandRunnerProvider.notifier);
  });

  tearDown(() => container.dispose());

  /// Runs action [id] with [command], reporting build errors.
  Future<bool> run(String id, Future<int> Function() command) => runner.run(
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

    expect(container.read(commandRunnerProvider).isRunning('build'), isTrue);

    exit.complete(1);
    expect(await done, isFalse);
    final runs = container.read(commandRunnerProvider);
    expect(runs.statusOf('build'), ActionStatus.error);
    expect(runs.logOf(_log).output, 'start\n');
    expect(runs.logOf(_log).errors, 'failed 1\n');
    expect(container.read(lastBuildErrorsProvider), 'failed 1\n');
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
    final runs = container.read(commandRunnerProvider);
    expect(runs.statusOf('run'), ActionStatus.idle);
    expect(runs.logOf(_log).output, contains('Stopped'));
  });

  test('a project change ends every run and forgets its log', () async {
    final exit = Completer<int>();
    final done = run('build', () => exit.future);

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
    ActionStatus status() =>
        container.read(commandRunnerProvider).statusOf('run');

    output.onOutput('building');
    expect(status(), ActionStatus.running);
    output.onOutput('ready');
    expect(status(), ActionStatus.live);
    expect(container.read(commandRunnerProvider).isRunning('run'), isTrue);

    exit.complete(0);
    await done;
    expect(status(), ActionStatus.success);
  });
}
