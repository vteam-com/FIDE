import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/models/preview_frame.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_settings.dart';
import 'package:fide/services/flutter_app_session.dart';
import 'package:fide/services/preview_registry.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter/painting.dart';

/// Runs a project's preview host: a [FlutterAppSession] on the headless
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
  FlutterAppSession? _session;
  PreviewSettings? _settings;

  /// Starts the host and completes once it runs; throws with its output
  /// when it can't start, such as when the project doesn't compile.
  Future<void> start() async {
    final server = _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen(_accept);
    final session = _session = FlutterAppSession(
      runner: _runner,
      projectPath: projectPath,
      arguments: [
        '--show-test-device',
        '-d',
        'flutter-tester',
        '-t',
        PreviewRegistry.entryPoint,
        '--dart-define=$_portDefine=${server.port}',
      ],
      onExit: onExit,
    );
    await session.launch();
    unawaited(session.exitCode.then((_) => server.close(force: true)));
    await session.started;
  }

  /// Hot restarts the host, so it renders what is on disk from a fresh
  /// state; returns null on success, else why it failed.
  Future<String?> restart() async =>
      await _session?.reload(full: true) ?? FlutterAppSession.notRunning;

  /// Hot reloads the host so it renders what is on disk, restarting it
  /// when the reload can't apply a change
  /// ([FlutterAppSession.reloadOrRestart]); returns null on success, else
  /// why it failed, with the compile errors.
  Future<String?> reload() async =>
      await _session?.reloadOrRestart() ?? FlutterAppSession.notRunning;

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

  /// Lays out the preview at [index] with its width ([Axis.horizontal])
  /// or height ([Axis.vertical]) at [length] logical pixels, or Auto when
  /// [length] is null.
  void resize(int index, Axis axis, double? length) {
    _send({
      'type': 'size',
      'index': index,
      'axis': axis == Axis.horizontal ? 'width' : 'height',
      'value': length,
    });
  }

  /// Stops the host and its server.
  Future<void> stop() async {
    await _session?.stop();
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

  /// Sends [message] to the host, once connected.
  void _send(Map<String, Object?> message) => _socket?.add(jsonEncode(message));
}
