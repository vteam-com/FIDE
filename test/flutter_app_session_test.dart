import 'package:fide/services/flutter_app_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_flutter_daemon.dart';

void main() {
  late FakeFlutterDaemon daemon;
  late FakeDaemonRunner runner;
  late List<String> output;
  late List<String> errors;
  late List<String> exits;
  late FlutterAppSession session;

  setUp(() {
    daemon = FakeFlutterDaemon();
    runner = FakeDaemonRunner(daemon);
    output = [];
    errors = [];
    exits = [];
    session = FlutterAppSession(
      runner: runner,
      projectPath: '/p',
      arguments: const ['-d', 'macos'],
      onOutput: output.add,
      onError: errors.add,
      onExit: exits.add,
    );
  });

  /// Launches [session] and waits for its app to start.
  Future<void> launchApp({bool supportsRestart = true}) async {
    await session.launch();
    daemon.launch(supportsRestart: supportsRestart);
    await session.started;
  }

  test('runs flutter run --machine and reports what the tool says', () async {
    await session.launch();
    daemon
      ..event('app.progress', {'message': 'Building macOS application...'})
      ..line('plain build line')
      ..event('daemon.logMessage', {'level': 'error', 'message': 'boom'})
      ..errorLine('on stderr')
      ..event('app.log', {'log': 'app print'})
      ..event('app.log', {'log': 'app error', 'error': true})
      ..launch();
    await session.started;

    expect(runner.commands, ['flutter run --machine -d macos']);
    expect(session.supportsRestart, isTrue);
    expect(output, [
      'Building macOS application...',
      'plain build line',
      'app print',
    ]);
    // stdout and stderr interleave in any order
    expect(errors, unorderedEquals(['boom', 'on stderr', 'app error']));
  });

  test('a start fails with the output when the tool exits first', () async {
    await session.launch();
    daemon.line("lib/main.dart:1:2: Error: Expected ';'");
    await daemon.exit(1);

    await expectLater(
      session.started,
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains(';')),
      ),
    );
    expect(await session.exitCode, 1);
    expect(exits, isEmpty);
  });

  test('a release app does not hot reload', () async {
    await launchApp(supportsRestart: false);

    expect(session.supportsRestart, isFalse);
  });

  test('a hot reload asks the tool, which logs how it went', () async {
    daemon.answer = (_, _) {
      daemon.event('daemon.logMessage', {
        'level': 'status',
        'message': 'Reloaded 2 of 9 libraries in 80ms.',
      });
      return {'code': 0, 'message': 'Reloaded 2 of 9 libraries'};
    };
    await launchApp();

    expect(await session.reload(), isNull);
    expect(daemon.requests.single.method, 'app.restart');
    expect(daemon.requests.single.params, {
      'appId': fakeAppId,
      'fullRestart': false,
      'pause': false,
    });
    expect(output, ['Reloaded 2 of 9 libraries in 80ms.']);
  });

  test('a failed reload returns the errors since it began', () async {
    await launchApp();
    // More than the output kept, so the oldest lines are dropped
    for (var i = 0; i < 500; i++) {
      daemon.line('line $i');
    }
    await pumpEventQueue();
    daemon.answer = (_, _) {
      daemon.line("lib/a.dart:3:4: Error: Expected ';'");
      return {'code': 1, 'message': 'Compile failed'};
    };

    final error = await session.reload();

    expect(error, "Compile failed\nlib/a.dart:3:4: Error: Expected ';'");
    expect(errors, ['Compile failed']);
  });

  test(
    'restarts when a hot reload is rejected, not on a compile error',
    () async {
      await launchApp();
      var restarts = 0;
      daemon.answer = (_, params) => params['fullRestart'] == true
          ? {'code': 0, 'message': ''}
          : {'code': 1, 'message': 'Reload rejected: const class changed'};

      expect(
        await session.reloadOrRestart(onRestart: () => restarts++),
        isNull,
      );
      expect(restarts, 1);
      expect(
        [for (final r in daemon.requests) r.params['fullRestart']],
        [false, true],
      );

      daemon.requests.clear();
      daemon.answer = (_, _) => {'code': 1, 'message': "a.dart:1:2: Error: x"};
      expect(
        await session.reloadOrRestart(onRestart: () => restarts++),
        isNotNull,
      );
      expect(restarts, 1);
      expect(daemon.requests, hasLength(1));
    },
  );

  test('stop asks the tool to stop the app, then kills it', () async {
    await launchApp();

    await session.stop();

    expect(daemon.methods, ['app.stop']);
    expect(daemon.requests.single.params, {'appId': fakeAppId});
    expect(daemon.killed, isTrue);
    expect(await session.exitCode, 0);
    expect(exits, isEmpty);
    expect(await session.reload(), FlutterAppSession.notRunning);
  });

  test('tells when the app exits by itself', () async {
    await launchApp();
    daemon.line('bye');

    await daemon.exit(0);

    expect(await session.exitCode, 0);
    expect(exits, ['bye']);
    expect(session.supportsRestart, isFalse);
  });
}
