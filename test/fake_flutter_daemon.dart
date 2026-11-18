import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/services/process_runner.dart';

/// Id of the app a [FakeFlutterDaemon] runs.
const String fakeAppId = 'app-1';

/// A `flutter run --machine` process for tests: it writes the daemon
/// messages a test asks for, records the requests written to its stdin and
/// answers them with [answer].
class FakeFlutterDaemon implements Process {
  /// Creates a running daemon answering each request with [answer].
  FakeFlutterDaemon({this.answer = _succeed}) {
    _stdinLines.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onRequest);
  }

  /// The result of each request, from its method and params.
  Object? Function(String method, Map<String, Object?> params) answer;

  /// The requests written to stdin: their method and params.
  final List<({String method, Map<String, Object?> params})> requests = [];

  /// Whether [kill] was called.
  bool killed = false;

  final StreamController<List<int>> _stdout = StreamController();
  final StreamController<List<int>> _stderr = StreamController();
  final StreamController<List<int>> _stdinLines = StreamController();
  final Completer<int> _exitCode = Completer();
  bool _exiting = false;

  @override
  late final IOSink stdin = IOSink(_stdinLines);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  int get pid => 1;

  /// The methods of [requests], in order.
  List<String> get methods => [for (final r in requests) r.method];

  /// Writes event [name] with [params].
  void event(String name, [Map<String, Object?> params = const {}]) => line(
    jsonEncode([
      {'event': name, 'params': params},
    ]),
  );

  /// Writes [text] on stdout.
  void line(String text) => _stdout.add(utf8.encode('$text\n'));

  /// Writes [text] on stderr.
  void errorLine(String text) => _stderr.add(utf8.encode('$text\n'));

  /// Writes the events of an app that has launched; [supportsRestart] is
  /// false in release mode.
  void launch({bool supportsRestart = true}) {
    event('app.start', {
      'appId': fakeAppId,
      'supportsRestart': supportsRestart,
    });
    event('app.started', {'appId': fakeAppId});
  }

  /// Exits with [code], closing its output; once only.
  Future<void> exit(int code) async {
    if (_exiting) return;
    _exiting = true;
    await _stdout.close();
    await _stderr.close();
    _exitCode.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    unawaited(exit(-1));
    return true;
  }

  /// Records the request on [text] and writes its answer.
  void _onRequest(String text) {
    final request = (jsonDecode(text) as List).first as Map<String, Object?>;
    final method = request['method']! as String;
    final params = request['params']! as Map<String, Object?>;
    requests.add((method: method, params: params));
    if (method == 'app.stop') {
      line(
        jsonEncode([
          {'id': request['id'], 'result': true},
        ]),
      );
      unawaited(exit(0));
      return;
    }
    line(
      jsonEncode([
        {'id': request['id'], 'result': answer(method, params)},
      ]),
    );
  }

  /// Answers a request with success.
  static Object? _succeed(String method, Map<String, Object?> params) => {
    'code': 0,
    'message': '',
  };
}

/// A [ProcessRunner] whose [start] runs [daemon] and records the command.
class FakeDaemonRunner extends ProcessRunner {
  /// Creates the runner starting [daemon].
  FakeDaemonRunner(this.daemon);

  /// The process every [start] returns.
  final FakeFlutterDaemon daemon;

  /// Each command started, its executable and arguments joined.
  final List<String> commands = [];

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    commands.add([executable, ...arguments].join(' '));
    return daemon;
  }
}
