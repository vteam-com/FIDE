import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/models/flutter_daemon_message.dart';
import 'package:fide/models/preview_frame.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_settings.dart';
import 'package:fide/services/preview_registry.dart';
import 'package:fide/services/process_runner.dart';

/// Runs a project's preview host: `flutter run --machine` on the headless
/// `flutter-tester` device, hot reloaded as files change, talking to FIDE
/// over a WebSocket on the loopback interface.
///
/// The host is a Dart VM app, so previews can use `dart:io` and the
/// project's assets by their usual paths, unlike the web-based previewer
/// of `flutter widget-preview`. Native plugins aren't available.
class PreviewHost {
  /// Creates the host of the project at [projectPath]; [start] runs it.
  PreviewHost({
    required this._runner,
    required this.projectPath,
    required this.onPreviews,
    required this.onFrame,
    required this.onLog,
    required this.onExit,
  });

  /// The `--dart-define` telling the host the port of FIDE's server.
  static const String _portDefine = 'FIDE_PREVIEW_PORT';

  /// How long [stop] waits for the app to stop before killing it.
  static const Duration _stopTimeout = Duration(seconds: 5);

  /// Most lines of output kept for the error shown when a start or a
  /// reload fails.
  static const int _maxOutputLines = 400;

  final ProcessRunner _runner;

  /// The project's root folder.
  final String projectPath;

  /// Called with the previews the host lists, after each start and reload.
  final void Function(int generation, List<PreviewItem> items) onPreviews;

  /// Called with each frame the host sends.
  final void Function(PreviewFrame frame) onFrame;

  /// Called with each error the previews report while running.
  final void Function(String message) onLog;

  /// Called with the latest output when the host exits by itself.
  final void Function(String output) onExit;

  HttpServer? _server;
  WebSocket? _socket;
  Process? _process;
  String? _appId;
  PreviewSettings? _settings;
  bool _stopping = false;
  int _nextRequestId = 1;
  final Map<int, Completer<FlutterDaemonMessage>> _requests = {};
  final Completer<void> _started = Completer<void>();
  final List<String> _output = [];

  /// Starts the host and completes once it runs; throws with its output
  /// when it can't start, such as when the project doesn't compile.
  Future<void> start() async {
    final server = _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen(_accept);
    final process = _process = await _runner.start('flutter', [
      'run',
      '--machine',
      '--show-test-device',
      '-d',
      'flutter-tester',
      '-t',
      PreviewRegistry.entryPoint,
      '--dart-define=$_portDefine=${server.port}',
    ], workingDirectory: projectPath);
    _lines(process.stdout).listen(_onLine);
    _lines(process.stderr).listen(_addOutput);
    unawaited(process.exitCode.then(_exited));
    await _started.future;
  }

  /// Hot reloads the host, or hot restarts it when [full], so it renders
  /// what is on disk; returns null on success, else why it failed, with
  /// the compile errors.
  Future<String?> reload({bool full = false}) async {
    final appId = _appId;
    if (appId == null) return 'The preview host is not running';
    final from = _output.length;
    final answer = await _request('app.restart', {
      'appId': appId,
      'fullRestart': full,
      'pause': false,
    });
    if (answer.succeeded) return null;
    return [
      answer.resultMessage,
      ..._output.skip(from),
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }

  /// Sends the render [settings], now and to a host that connects later.
  void configure(PreviewSettings settings) {
    _settings = settings;
    _send(settings.toJson());
  }

  /// Forwards a pointer event of the preview at [index], at logical
  /// position ([x], [y]) in it: [phase] is `down`, `move`, `up` or
  /// `scroll`, the last by ([dx], [dy]).
  void pointer(
    int index,
    String phase,
    double x,
    double y, {
    double dx = 0,
    double dy = 0,
  }) {
    _send({
      'type': 'pointer',
      'index': index,
      'phase': phase,
      'x': x,
      'y': y,
      'dx': dx,
      'dy': dy,
    });
  }

  /// Stops the host and its server.
  Future<void> stop() async {
    _stopping = true;
    final appId = _appId;
    if (appId != null) {
      await _request('app.stop', {
        'appId': appId,
      }).timeout(_stopTimeout, onTimeout: () => const FlutterDaemonMessage());
    }
    _process?.kill();
    await _socket?.close();
    await _server?.close(force: true);
  }

  /// Takes the host's WebSocket connection.
  Future<void> _accept(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = _socket = await WebSocketTransformer.upgrade(request);
    final settings = _settings;
    if (settings != null) configure(settings);
    socket.listen(_onSocketMessage);
  }

  /// Handles a host message: a frame as bytes, else a JSON preview list
  /// or log.
  void _onSocketMessage(Object? data) {
    if (data is List<int>) {
      final frame = PreviewFrame.decode(data);
      if (frame != null) onFrame(frame);
      return;
    }
    if (data is! String) return;
    final message = jsonDecode(data);
    if (message is! Map<String, Object?>) return;
    switch (message['type']) {
      case 'previews':
        final items = message['items'] as List? ?? const [];
        onPreviews(message['generation'] as int? ?? 0, [
          for (final item in items.whereType<Map<String, Object?>>())
            PreviewItem.fromJson(item),
        ]);
      case 'log':
        onLog(message['message'] as String? ?? '');
    }
  }

  /// Handles a line of `flutter run` output: an answer, an event or
  /// plain output kept for errors.
  void _onLine(String line) {
    final message = FlutterDaemonMessage.parse(line);
    if (message == null) {
      _addOutput(line);
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
      case 'app.started':
        if (!_started.isCompleted) _started.complete();
    }
    final text = message.logText;
    if (text != null) _addOutput(text);
  }

  /// Keeps [line], the latest [_maxOutputLines] only.
  void _addOutput(String line) {
    _output.add(line);
    if (_output.length > _maxOutputLines) _output.removeAt(0);
  }

  /// Fails the pending requests and the start, or reports the exit.
  void _exited(int exitCode) {
    _appId = null;
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
    unawaited(_server?.close(force: true));
  }

  /// Sends daemon request [method] with [params] and waits for its
  /// answer.
  Future<FlutterDaemonMessage> _request(
    String method,
    Map<String, Object?> params,
  ) {
    final process = _process;
    if (process == null) {
      return Future.value(const FlutterDaemonMessage(error: 'Not running'));
    }
    final id = _nextRequestId++;
    final answer = _requests[id] = Completer<FlutterDaemonMessage>();
    process.stdin.writeln(FlutterDaemonMessage.request(id, method, params));
    return answer.future;
  }

  /// Sends [message] to the host, once connected.
  void _send(Map<String, Object?> message) => _socket?.add(jsonEncode(message));

  /// The lines of a process output stream.
  static Stream<String> _lines(Stream<List<int>> bytes) =>
      bytes.transform(utf8.decoder).transform(const LineSplitter());
}
