import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fide/models/flutter_daemon_message.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';

/// One app run by `flutter run --machine`: built and launched, then hot
/// reloaded, hot restarted and stopped through the Flutter daemon
/// protocol, as requests written to the tool's stdin and answered on its
/// stdout.
///
/// Unlike an interactive `flutter run`, the tool in machine mode doesn't
/// stop the app when it is killed, so [stop] asks it to first.
class FlutterAppSession {
  /// Creates the session running `flutter run --machine` with [arguments]
  /// (device, mode, entry point...) in [projectPath]; [launch] starts it.
  FlutterAppSession({
    required this._runner,
    required this.projectPath,
    required this.arguments,
    this.onOutput = _ignore,
    this.onError = _ignore,
    this.onExit = _ignore,
  });

  /// Why a reload fails before the app runs.
  static const String notRunning = 'The app is not running';

  /// How the compiler starts an error, after its `file:line:column`.
  static const String _compileError = ': Error: ';

  /// Most lines of output kept for the error a failed start or reload
  /// returns.
  static const int _maxOutputLines = 400;

  /// How long [stop] waits for the app to stop before killing the tool.
  static const Duration _stopTimeout = Duration(seconds: 5);

  final ProcessRunner _runner;

  /// What `flutter run --machine` is given after its own flags.
  final List<String> arguments;

  /// Receives each line of error output: the tool's errors, such as
  /// compile errors, the app's error output, and why a reload failed.
  final void Function(String line) onError;

  /// Called with the latest output when the app exits by itself, after it
  /// started.
  final void Function(String output) onExit;

  /// Receives each other line the tool or the app reports, such as build
  /// steps, the app's prints and how long a reload took.
  final void Function(String line) onOutput;

  /// The project's root folder, where the tool runs.
  final String projectPath;

  Process? _process;
  String? _appId;
  bool _supportsRestart = false;
  bool _stopping = false;
  int _nextRequestId = 1;
  final Map<int, Completer<FlutterDaemonMessage>> _requests = {};
  final Completer<void> _started = Completer<void>();
  final Completer<int> _exitCode = Completer<int>();

  /// The latest lines of output, at most [_maxOutputLines].
  final List<String> _output = [];

  /// How many lines of output came, including those [_output] dropped.
  int _outputCount = 0;

  /// Completes with the tool's exit code once it has exited and its output
  /// has been reported.
  Future<int> get exitCode => _exitCode.future;

  /// Completes once the app runs; fails with a [StateError] holding the
  /// output when the tool exits first, such as when the project doesn't
  /// compile.
  Future<void> get started => _started.future;

  /// Whether the running app hot reloads and restarts; false in release
  /// mode, and before the app starts or after it stops.
  bool get supportsRestart => _supportsRestart;

  /// Starts `flutter run --machine` and returns its process; [started]
  /// then tells when the app runs, and [exitCode] when the tool exits.
  Future<Process> launch() async {
    // Nothing has to wait for the start: a failed one is not unhandled
    _started.future.ignore();
    final process = _process = await _runner.start(
      FlutterSdk.executable,
      ['run', '--machine', ...arguments],
      workingDirectory: projectPath,
      runInShell: true,
    );
    // Writing a request as the tool exits fails its stdin, not FIDE
    process.stdin.done.ignore();
    final drained = Future.wait([
      _lines(process.stdout).forEach(_onLine),
      _lines(process.stderr).forEach((line) => _report(line, isError: true)),
    ]).catchError((Object _) => const <void>[]);
    unawaited(
      process.exitCode.then((code) async {
        await drained;
        _exited(code);
      }),
    );
    return process;
  }

  /// Hot reloads the app, or hot restarts it when [full], so it runs what
  /// is on disk; returns null on success, else why it failed, with the
  /// compile errors.
  Future<String?> reload({bool full = false}) async {
    final appId = _appId;
    if (appId == null) return notRunning;
    final countBefore = _outputCount;
    final answer = await _request('app.restart', {
      'appId': appId,
      'fullRestart': full,
      'pause': false,
    });
    // The tool logs how a reload went, but not why one failed
    if (answer.succeeded) return null;
    final message = answer.resultMessage;
    if (message.isNotEmpty) onError(message);
    final since = min(_outputCount - countBefore, _output.length);
    return [
      message,
      ..._output.skip(_output.length - since),
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }

  /// Hot reloads the app and, when the reload can't apply a change, such
  /// as to a class's shape, hot restarts it, calling [onRestart] first; a
  /// compile error would only fail again, so it doesn't restart. Returns
  /// null on success, else why it failed.
  Future<String?> reloadOrRestart({void Function()? onRestart}) async {
    final error = await reload();
    if (error == null || error.contains(_compileError)) return error;
    onRestart?.call();
    return reload(full: true);
  }

  /// Asks the tool to stop the app, waiting at most [_stopTimeout], then
  /// kills the tool.
  Future<void> stop() async {
    _stopping = true;
    final appId = _appId;
    if (appId != null) {
      await _request('app.stop', {
        'appId': appId,
      }).timeout(_stopTimeout, onTimeout: () => const FlutterDaemonMessage());
    }
    _process?.kill();
  }

  /// Handles a line of `flutter run` output: an answer, an event, or plain
  /// output.
  void _onLine(String line) {
    final message = FlutterDaemonMessage.parse(line);
    if (message == null) {
      _report(line, isError: false);
      return;
    }
    final id = message.id;
    if (id != null) {
      _requests.remove(id)?.complete(message);
      return;
    }
    switch (message.event) {
      case 'app.start':
        _appId = message.params['appId'] as String?;
        _supportsRestart = message.params['supportsRestart'] == true;
      case 'app.started':
        if (!_started.isCompleted) _started.complete();
    }
    final text = message.logText;
    if (text != null) _report(text, isError: message.isError);
  }

  /// Keeps [line], the latest [_maxOutputLines] only, and reports it,
  /// unless it is blank.
  void _report(String line, {required bool isError}) {
    if (line.trim().isEmpty) return;
    _output.add(line);
    _outputCount++;
    if (_output.length > _maxOutputLines) _output.removeAt(0);
    (isError ? onError : onOutput)(line);
  }

  /// Fails the pending requests and the start, or reports the exit.
  void _exited(int exitCode) {
    _appId = null;
    _supportsRestart = false;
    for (final request in _requests.values) {
      request.complete(FlutterDaemonMessage(error: 'Exited with $exitCode'));
    }
    _requests.clear();
    final output = _output.join('\n');
    if (!_started.isCompleted) {
      _started.completeError(StateError(output));
    } else if (!_stopping) {
      onExit(output);
    }
    _exitCode.complete(exitCode);
  }

  /// Sends daemon request [method] with [params] and waits for its
  /// answer.
  Future<FlutterDaemonMessage> _request(
    String method,
    Map<String, Object?> params,
  ) {
    final process = _process;
    if (process == null) {
      return Future.value(const FlutterDaemonMessage(error: notRunning));
    }
    final id = _nextRequestId++;
    final answer = _requests[id] = Completer<FlutterDaemonMessage>();
    process.stdin.writeln(FlutterDaemonMessage.request(id, method, params));
    return answer.future;
  }

  /// Ignores a line or an output.
  static void _ignore(String _) {}

  /// The lines of a process output stream.
  static Stream<String> _lines(Stream<List<int>> bytes) => bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
}
