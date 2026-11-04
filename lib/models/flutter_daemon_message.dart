import 'dart:convert';

/// One message `flutter run --machine` writes on a line of its output: an
/// event, such as `app.started`, or the answer to a request FIDE sent.
class FlutterDaemonMessage {
  /// Creates the message.
  const FlutterDaemonMessage({
    this.id,
    this.event,
    this.params = const {},
    this.result,
    this.error,
  });

  /// The id of the request this message answers; null for an event.
  final int? id;

  /// The event's name, such as `app.log`; null for an answer.
  final String? event;

  /// The event's parameters.
  final Map<String, Object?> params;

  /// The request's result.
  final Object? result;

  /// Why the request failed; null when it didn't.
  final Object? error;

  /// The message on output [line], or null when the line is plain text
  /// (a compile error, a build step) rather than a daemon message.
  static FlutterDaemonMessage? parse(String line) {
    final text = line.trim();
    if (!text.startsWith('[{') || !text.endsWith('}]')) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;
    final message = decoded.first;
    if (message is! Map<String, Object?>) return null;
    final params = message['params'];
    return FlutterDaemonMessage(
      id: message['id'] is int ? message['id'] as int : null,
      event: message['event'] as String?,
      params: params is Map<String, Object?> ? params : const {},
      result: message['result'],
      error: message['error'],
    );
  }

  /// A request line for the daemon: [method] with [params], as request
  /// [id].
  static String request(int id, String method, Map<String, Object?> params) =>
      jsonEncode([
        {'id': id, 'method': method, 'params': params},
      ]);

  /// Whether this answer reports success: no [error], and a `code` of 0
  /// when the result has one.
  bool get succeeded {
    if (error != null) return false;
    final result = this.result;
    return result is! Map || (result['code'] ?? 0) == 0;
  }

  /// The answer's message, such as why a reload failed; empty without one.
  String get resultMessage {
    final result = this.result;
    final message = result is Map ? result['message'] : null;
    return '${message ?? error ?? ''}';
  }

  /// The text a log event carries; null for other messages.
  String? get logText => switch (event) {
    'app.log' => params['log'] as String?,
    'daemon.logMessage' || 'app.progress' => params['message'] as String?,
    _ => null,
  };
}
