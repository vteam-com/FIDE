import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fide/providers/terminal_providers.dart';
import 'package:fide/services/terminal_session.dart';
import 'package:flutter_pty2/flutter_pty2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what is written to the shell.
class _FakeInput implements PtyInput {
  final List<String> written = [];

  bool closed = false;

  @override
  Future<void> flush() async {}

  @override
  PtyWriteResult tryWrite(Uint8List data) => PtyWriteResult.accepted;

  @override
  Future<void> write(Uint8List data) async {
    if (closed) throw StateError('closed');
    written.add(utf8.decode(data));
  }
}

/// A shell whose output the test feeds.
class _FakePty implements PtySession {
  _FakePty(this.options);

  final PtySpawnOptions options;

  final StreamController<Uint8List> _output = StreamController();

  @override
  final _FakeInput input = _FakeInput();

  int kills = 0;

  bool closed = false;

  /// Prints [text] as the shell would.
  void print(String text) => _output.add(Uint8List.fromList(utf8.encode(text)));

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  void kill() => kills++;

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<_FakePty> spawned;
  late Completer<void> spawning;
  late TerminalSession session;
  late List<String> output;

  setUp(() {
    spawned = [];
    spawning = Completer()..complete();
    session = TerminalSession(
      spawn: (options) async {
        await spawning.future;
        final pty = _FakePty(options);
        spawned.add(pty);
        return pty;
      },
      environment: () async => {'PATH': '/opt/bin'},
    );
    output = [];
    session.output.listen(output.add);
  });

  tearDown(() => session.dispose());

  test('starts the shell in the folder with the login PATH', () async {
    expect(await session.start(workingDirectory: '/project'), isTrue);

    final options = spawned.single.options;
    expect(options.executable, TerminalSession.shellPath);
    expect(options.workingDirectory, '/project');
    final environment = options.environment as PtyInheritedEnvironment;
    expect(environment.overrides, {
      'PATH': '/opt/bin',
      'TERM': TerminalSession.terminalType,
    });
    expect(session.isRunning, isTrue);
    expect(session.workingDirectory, '/project');
  });

  test('defaults to the app folder', () async {
    await session.start();

    expect(spawned.single.options.workingDirectory, isNotEmpty);
  });

  test('decodes the shell output and sends the input', () async {
    await session.start(workingDirectory: '/project');

    spawned.single.print('héllo');
    await session.write('ls\n');
    await Future<void>.delayed(Duration.zero);

    expect(output, ['héllo']);
    expect(spawned.single.input.written, ['ls\n']);
  });

  test('write does nothing without a shell and ignores a closed one', () async {
    await session.write('ignored');
    await session.start(workingDirectory: '/project');
    spawned.single.input.closed = true;

    await session.write('lost');

    expect(spawned.single.input.written, isEmpty);
  });

  test('stop kills and closes the shell', () async {
    await session.start(workingDirectory: '/project');

    session.stop();

    expect(spawned.single.kills, 1);
    expect(spawned.single.closed, isTrue);
    expect(session.isRunning, isFalse);
    expect(session.workingDirectory, isNull);
  });

  test('a shell spawned after a stop or newer start is released', () async {
    spawning = Completer();
    final stale = session.start(workingDirectory: '/old');
    session.stop();
    spawning.complete();

    expect(await stale, isFalse);
    expect(spawned.single.kills, 1);
    expect(session.isRunning, isFalse);
  });

  test('the provider stops the shell when disposed', () async {
    final container = ProviderContainer(
      overrides: [terminalSessionProvider.overrideWithValue(session)],
    );
    expect(container.read(terminalSessionProvider), same(session));
    container.dispose();

    final real = ProviderContainer();
    expect(real.read(terminalSessionProvider), isA<TerminalSession>());
    real.dispose();
  });
}
