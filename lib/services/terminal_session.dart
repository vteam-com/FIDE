import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/services/login_shell_environment.dart';
import 'package:flutter_pty2/flutter_pty2.dart';

/// Spawns a pseudo-terminal running [options]; [Pty.spawn] outside tests.
typedef PtySpawner = Future<PtySession> Function(PtySpawnOptions options);

/// A shell in a pseudo-terminal: [start]ed in a folder, its [output]
/// decoded as UTF-8 text and the user's keystrokes [write]n to it.
class TerminalSession {
  /// Creates a session spawning shells with the spawner given, [Pty.spawn]
  /// by default, in the login shell's environment.
  TerminalSession({
    this._spawn = Pty.spawn,
    this._environment = LoginShellEnvironment.load,
  });

  /// The shell every session runs.
  static const String shellPath = '/bin/zsh';

  /// What the shell is told its terminal is, for colors and key codes.
  static const String terminalType = 'xterm-256color';

  /// Environment variable naming the terminal type.
  static const String _terminalTypeKey = 'TERM';

  final Future<Map<String, String>> Function() _environment;

  final PtySpawner _spawn;

  final StreamController<String> _output = StreamController.broadcast();

  /// Bumped per [start] and [stop] so a slow spawn can tell it is stale.
  int _generation = 0;

  bool _isDisposed = false;

  PtySession? _session;

  StreamSubscription<Uint8List>? _subscription;

  String? _workingDirectory;

  /// Whether a shell is running.
  bool get isRunning => _session != null;

  /// What the shell prints, decoded as UTF-8.
  Stream<String> get output => _output.stream;

  /// The folder the running shell started in; null while none runs.
  String? get workingDirectory => _workingDirectory;

  /// Stops the shell and closes [output].
  void dispose() {
    stop();
    _isDisposed = true;
    unawaited(_output.close());
  }

  /// Starts a shell in [workingDirectory], the app's own folder by
  /// default, stopping the running one first; returns whether the shell
  /// is the running one once spawned, false when [stop], [dispose] or a
  /// newer [start] came first. Throws when the shell can't be spawned.
  Future<bool> start({String? workingDirectory}) async {
    stop();
    final generation = _generation;
    final folder = workingDirectory ?? Directory.current.path;
    final session = await _spawn(
      PtySpawnOptions(
        executable: shellPath,
        workingDirectory: folder,
        environment: PtyEnvironment.inherit(
          overrides: {...await _environment(), _terminalTypeKey: terminalType},
        ),
      ),
    );
    if (_isDisposed || generation != _generation) {
      _release(session);
      return false;
    }
    _session = session;
    _workingDirectory = folder;
    _subscription = session.output.listen(
      (data) => _output.add(utf8.decode(data, allowMalformed: true)),
    );
    return true;
  }

  /// Kills the running shell, if any, and releases its pseudo-terminal.
  void stop() {
    _generation++;
    final session = _session;
    _session = null;
    _workingDirectory = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (session != null) _release(session);
  }

  /// Sends [text] to the shell as the user's input; nothing without a
  /// running shell, and a shell that exited meanwhile is ignored.
  Future<void> write(String text) async {
    final session = _session;
    if (session == null) return;
    try {
      await session.input.write(Uint8List.fromList(utf8.encode(text)));
    } catch (_) {
      // The shell exited
    }
  }

  /// Kills [session], tolerating one that already exited, and closes it.
  static void _release(PtySession session) {
    try {
      session.kill();
    } catch (_) {
      // The shell already exited
    }
    unawaited(session.close());
  }
}
