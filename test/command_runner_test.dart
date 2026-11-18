import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/hot_reload.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_flutter_daemon.dart';
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
    expect(runs.logOf(_log).output, isEmpty);
  });

  group('an app run', () {
    late FakeFlutterDaemon daemon;

    setUp(() => daemon = FakeFlutterDaemon());

    /// Runs the app of action [id] in debug mode, or release, through the
    /// fake daemon, and lets it launch.
    Future<Future<bool>> runApp({
      String id = 'debug',
      bool isDebug = true,
      CommandRunner? on,
    }) async {
      final runs = on ?? runner;
      final done = runs.run(
        id,
        logKey: _log,
        startMessages: const [],
        command: (output) =>
            FlutterBuildService(FakeDaemonRunner(daemon))
                .run('/p', 'macos', output, isDebug: isDebug),
        successMessage: 'ok',
        failureMessage: (code) => 'failed $code',
        errorPrefix: 'error: ',
        resetWhenDone: false,
        reportsBuildErrors: true,
      );
      await pumpEventQueue();
      expect(stateOf(runs).statusOf(id), ActionStatus.running);
      daemon.launch(supportsRestart: isDebug);
      await pumpEventQueue();
      return done;
    }

    ActionStatus status([String id = 'debug']) => stateOf(runner).statusOf(id);

    test('turns live once the app has launched', () async {
      final done = await runApp();

      expect(status(), ActionStatus.live);
      expect(stateOf(runner).isRunning('debug'), isTrue);
      expect(stateOf(runner).reloadable, {'debug'});

      await daemon.exit(0);
      await done;
      expect(status(), ActionStatus.success);
      expect(stateOf(runner).canReload, isFalse);
    });

    test('hot reloads, ringing meanwhile, and reports the errors', () async {
      daemon.answer = (_, _) => {'code': 1, 'message': "a.dart:1:2: Error: x"};
      final done = await runApp();

      final reload = runner.reloadApp('debug');
      expect(status(), ActionStatus.reloading);
      expect(stateOf(runner).isAnyBusy(['debug']), isTrue);
      await reload;

      expect(status(), ActionStatus.live);
      expect(buildErrors.last, contains('Error: x'));
      expect(stateOf(runner).logOf(_log).errors, contains('Error: x'));

      daemon.answer = (_, _) => {'code': 0, 'message': ''};
      await runner.reloadApp('debug', HotReload.restart);
      expect(daemon.requests.last.params['fullRestart'], isTrue);
      expect(buildErrors.last, isEmpty);

      runner.stop('debug');
      await done;
    });

    test('a reload asked while reloading follows it once', () async {
      final done = await runApp();

      final first = runner.reloadApp('debug');
      unawaited(runner.reloadApps());
      unawaited(runner.reloadApps(HotReload.restart));
      await first;

      expect(
        [for (final r in daemon.requests) r.params['fullRestart']],
        [false, true],
      );
      expect(status(), ActionStatus.live);

      runner.stop('debug');
      await done;
    });

    test('a release app does not hot reload', () async {
      final done = await runApp(id: 'run', isDebug: false);

      expect(status('run'), ActionStatus.live);
      expect(stateOf(runner).canReload, isFalse);
      await runner.reloadApps();
      expect(daemon.requests, isEmpty);

      runner.stop('run');
      await done;
    });

    test('stop asks the tool to stop the app and the run ends idle', () async {
      final done = await runApp();

      runner.stop('debug');

      expect(await done, isFalse);
      expect(daemon.methods, ['app.stop']);
      expect(status(), ActionStatus.idle);
      expect(stateOf(runner).logOf(_log).output, contains('Stopped'));
    });

    test('a save hot reloads the apps running', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final runs = container.read(commandRunnerProvider.notifier);
      final done = await runApp(on: runs);

      container.read(savedFilesRevisionProvider.notifier).state++;
      await pumpEventQueue();

      expect(daemon.methods, ['app.restart']);
      runs.stop('debug');
      await done;
    });
  });

  test('shows a burst of log lines in one update', () async {
    const lines = 500;
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
    );
    var publications = 0;
    final removeListener = runner.addListener(
      (_) => publications++,
      fireImmediately: false,
    );
    addTearDown(removeListener);

    for (var i = 0; i < lines; i++) {
      output.onOutput('line $i');
    }
    expect(publications, 0);
    // Written at once, shown with the next update
    expect(stateOf(runner).logOf(_log).output, contains('line ${lines - 1}'));

    await Future<void>.delayed(AppDuration.outputLogPublish * 2);
    expect(publications, 1);

    output.onOutput('last line');
    exit.complete(0);
    await done;
    // The end of the run shows its last lines at once
    expect(publications, 2);
    expect(stateOf(runner).logOf(_log).output, endsWith('last line\nok\n'));
  });

  test('narrates a failed flutter command in the log', () async {
    await runner.run(
      'clean',
      logKey: _log,
      startMessages: const [],
      command: (output) async => throw const BuildException('pub get', 1),
      successMessage: 'ok',
      failureMessage: (code) => 'failed $code',
      errorPrefix: 'error: ',
    );

    final log = stateOf(runner).logOf(_log);
    expect(log.errors, 'error: Flutter pub get failed with exit code 1\n');
  });
}
