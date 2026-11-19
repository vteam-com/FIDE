import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/services/chat_model.dart';
import 'package:http/http.dart' as http;

/// Sends the requests of a model service, such as Ollama, and reads its
/// answers as they stream in, one JSON object per line ([jsonLines]).
///
/// Every failure becomes an [AiServiceException] naming the [service]; a
/// request stopped through its [AiCancelToken] throws an
/// [AiCancelledException].
class ModelHttp {
  /// Creates the sender of [service]'s requests through [_client];
  /// [unreachableHint] tells how to fix a service that can't be reached,
  /// and [slowHint] why it may answer too late.
  const ModelHttp(
    this._client, {
    required this.service,
    required this.unreachableHint,
    this.slowHint = '',
  });

  final http.Client _client;

  /// The service's name, as failures name it, such as `Ollama`.
  final String service;

  /// How to fix the service being unreachable.
  final String unreachableHint;

  /// Why the service may answer too late, after the timeout's message.
  final String slowHint;

  /// Statuses of a busy or failing server, worth a retry, such as the
  /// error Ollama answers when the model wrote a malformed tool call.
  static const Set<int> _retryableStatuses = {
    HttpStatus.internalServerError,
    HttpStatus.serviceUnavailable,
  };

  /// Runs [request] again while it fails with a retryable
  /// [AiServiceException], such as a busy server or a local model that
  /// wrote a malformed tool call, at most [AppMetric.aiRequestRetries]
  /// more times; [request] gets the number of the retry, 0 at first, so a
  /// retry can differ from the request that failed. [cancel] stops the
  /// retries.
  static Future<T> retrying<T>(
    Future<T> Function(int retry) request, {
    AiCancelToken? cancel,
  }) async {
    for (var retry = 0; ; retry++) {
      try {
        return await request(retry);
      } on AiCancelledException {
        rethrow;
      } on AiServiceException catch (e) {
        if (!e.isRetryable || retry >= AppMetric.aiRequestRetries) rethrow;
      }
      cancel?.throwIfCancelled();
    }
  }

  /// The JSON object answering a request that doesn't stream, or null
  /// when the answer isn't one; see [lines].
  Future<Map<String, dynamic>?> json(
    Uri uri,
    Duration timeout, {
    Map<String, String> headers = const {},
    Object? body,
    AiCancelToken? cancel,
  }) async {
    final text = await lines(
      uri,
      timeout,
      headers: headers,
      body: body,
      cancel: cancel,
    ).join('\n');
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      return null;
    }
    return data is Map<String, dynamic> ? data : null;
  }

  /// The JSON objects of the answer, one per line, as Ollama streams them;
  /// see [lines]. An object reporting an error throws it.
  Stream<Map<String, dynamic>> jsonLines(
    Uri uri,
    Duration timeout, {
    Map<String, String> headers = const {},
    Object? body,
    AiCancelToken? cancel,
  }) => _objects(
    lines(uri, timeout, headers: headers, body: body, cancel: cancel),
  );

  /// Sends [body] as JSON to [uri], or gets it when [body] is null, with
  /// [headers], and streams the lines of the answer as they arrive.
  ///
  /// Throws an [AiServiceException] when the service can't be reached,
  /// answers with an error status, or doesn't answer in full within
  /// [timeout] (the request is then aborted, so the model stops
  /// generating), and an [AiCancelledException] when [cancel] stops it.
  Stream<String> lines(
    Uri uri,
    Duration timeout, {
    Map<String, String> headers = const {},
    Object? body,
    AiCancelToken? cancel,
  }) async* {
    cancel?.throwIfCancelled();
    // A local model answers only once it has read the whole prompt: the
    // deadline covers the wait for the answer, not just reading it
    final deadline = Completer<void>();
    final timer = Timer(timeout, deadline.complete);
    final request = http.AbortableRequest(
      body == null ? 'GET' : 'POST',
      uri,
      abortTrigger: Future.any([?cancel?.whenCancelled, deadline.future]),
    )..headers.addAll(headers);
    if (body != null) {
      request.headers[HttpHeaders.contentTypeHeader] =
          ContentType.json.mimeType;
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        final answer = await response.stream.bytesToString();
        throw AiServiceException(
          '$service answered ${response.statusCode}: '
          '${_errorIn(_decoded(answer)) ?? answer}',
          isRetryable: _retryableStatuses.contains(response.statusCode),
        );
      }
      // Not `yield*`, which would pass a failure mid-answer, such as the
      // abort, past the catches below
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        yield line;
      }
    } on http.RequestAbortedException {
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
      throw AiServiceException(
        '$service gave no answer within ${timeout.inSeconds} s$slowHint.',
      );
    } on AiServiceException {
      rethrow;
    } catch (e) {
      throw AiServiceException('$e\n\n$unreachableHint');
    } finally {
      timer.cancel();
    }
  }

  /// The JSON value of [text], or null when it is none.
  static Object? _decoded(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// The error message [data] reports, as Ollama does
  /// (`{"error": "…"}`); null when it reports none.
  static String? _errorIn(Object? data) => switch (data) {
    {'error': final String message} => message,
    _ => null,
  };

  /// The JSON objects of [texts], skipping blank lines and other values;
  /// one reporting an error, as a server does when it fails mid-answer,
  /// throws it as a retryable [AiServiceException].
  Stream<Map<String, dynamic>> _objects(Stream<String> texts) async* {
    await for (final text in texts) {
      final data = _decoded(text);
      if (data is! Map<String, dynamic>) continue;
      final error = _errorIn(data);
      if (error != null) {
        throw AiServiceException('$service: $error', isRetryable: true);
      }
      yield data;
    }
  }
}
