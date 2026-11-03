import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/chat_model.dart';
import 'package:http/http.dart' as http;

/// The local Ollama model as a [ChatModel]: picks the model among the
/// downloaded ones and sends prompts and chats to Ollama's HTTP API.
///
/// Failed requests throw an [AiServiceException]; requests stopped through
/// their [AiCancelToken] throw an [AiCancelledException].
class OllamaClient implements ChatModel {
  /// Host and port Ollama listens on by default.
  static const String ollamaHost = 'localhost:11434';

  /// Path of Ollama's one-shot generation endpoint.
  static const String _generatePath = '/api/generate';

  /// Path of Ollama's chat endpoint, which supports tool calling.
  static const String _chatPath = '/api/chat';

  /// Path of Ollama's endpoint describing one model.
  static const String _showPath = '/api/show';

  /// Path of Ollama's endpoint listing downloaded models.
  static const String _tagsPath = '/api/tags';

  /// Capability Ollama reports for models that can call tools.
  static const String _toolsCapability = 'tools';

  /// Capability Ollama reports for models that reason before answering.
  static const String _thinkingCapability = 'thinking';

  final http.Client _client;

  String _model = AiModel.ollama;
  bool _isModelResolved = false;
  bool _supportsTools = true;
  bool _supportsThinking = false;

  /// Creates a client sending requests through [_client].
  OllamaClient(this._client);

  /// Whether [model] stands in for [AiModel.ollama], which isn't
  /// downloaded or can't call tools.
  bool get isFallbackModel => !_isPreferred(_model);

  /// The model requests go to; see [resolveModel].
  String get model => _model;

  /// Whether [model] can call tools, which editing files needs.
  bool get supportsTools => _supportsTools;

  /// Picks the model requests go to among the downloaded ones and returns
  /// it, or null when none is downloaded: [AiModel.ollama] first,
  /// then any model that can call tools, then any model.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached.
  Future<String?> resolveModel({AiCancelToken? cancel}) async {
    final tags = await _send(
      _tagsPath,
      AppDuration.aiSuggestionTimeout,
      cancel: cancel,
    );
    final listed = tags?['models'];
    final names = [
      if (listed is List)
        for (final entry in listed)
          if (entry is Map && entry['name'] is String) entry['name'] as String,
    ];
    if (names.isEmpty) return null;
    final candidates = [
      ...names.where(_isPreferred),
      ...names.where((name) => !_isPreferred(name)),
    ];
    var chosen = candidates.first;
    List<Object?>? capabilities;
    var canCallTools = false;
    for (final name in candidates) {
      final listed = await _capabilities(name, cancel);
      if (name == chosen) capabilities = listed;
      if (_canCallTools(listed)) {
        chosen = name;
        capabilities = listed;
        canCallTools = true;
        break;
      }
    }
    _model = chosen;
    _supportsTools = canCallTools;
    _supportsThinking = capabilities?.contains(_thinkingCapability) ?? false;
    _isModelResolved = true;
    return chosen;
  }

  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
  }) async {
    final data = await _post(
      _generatePath,
      {'prompt': prompt},
      timeout,
      think: think,
      cancel: cancel,
    );
    return data?['response']?.toString() ?? '';
  }

  @override
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
  }) async {
    final data = await _post(
      _chatPath,
      {'messages': messages, 'tools': tools},
      AppDuration.aiToolStepTimeout,
      think: think,
      cancel: cancel,
    );
    final message = data?['message'];
    return message is Map<String, dynamic> ? message : const {};
  }

  /// The capabilities Ollama reports for [name], or null when it doesn't
  /// say, as older Ollama versions report none.
  Future<List<Object?>?> _capabilities(
    String name,
    AiCancelToken? cancel,
  ) async {
    final details = await _send(
      _showPath,
      AppDuration.aiSuggestionTimeout,
      body: {'model': name},
      cancel: cancel,
    );
    final capabilities = details?['capabilities'];
    return capabilities is List ? capabilities : null;
  }

  /// Whether [capabilities] let a model call tools; true when unknown.
  static bool _canCallTools(List<Object?>? capabilities) =>
      capabilities == null || capabilities.contains(_toolsCapability);

  /// Whether [name] is [AiModel.ollama] under any tag.
  bool _isPreferred(String name) =>
      name == AiModel.ollama || name.startsWith('${AiModel.ollama}:');

  /// Sends [body] (plus the model name) to Ollama's [path], resolving the
  /// model first when [resolveModel] hasn't, and returns the reply like
  /// [_send].
  ///
  /// A thinking model reasons before answering only when [think] is set:
  /// on a local model the hidden reasoning costs most of the time and
  /// energy of a request, so only tasks needing judgment ask for it. The
  /// model stays loaded for [AppDuration.aiModelKeepAlive] so the next
  /// request doesn't reload it, with one [AppMetric.aiContextTokens]
  /// context window for every request.
  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, Object> body,
    Duration timeout, {
    required bool think,
    required AiCancelToken? cancel,
  }) async {
    if (!_isModelResolved) {
      try {
        await resolveModel(cancel: cancel);
      } on AiCancelledException {
        rethrow;
      } on AiServiceException {
        // The request below reports the failure
      }
    }
    return _send(
      path,
      timeout,
      body: {
        'model': _model,
        'stream': false,
        'keep_alive': AppDuration.aiModelKeepAlive.inSeconds,
        'options': {'num_ctx': AppMetric.aiContextTokens},
        if (_supportsThinking) 'think': think,
        ...body,
      },
      cancel: cancel,
    );
  }

  /// Posts [body] to Ollama's [path], or gets it when [body] is null, and
  /// returns the decoded JSON reply, or null when it isn't a JSON object.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached within
  /// [timeout] or answers with an error status, and an
  /// [AiCancelledException] when [cancel] stops it.
  Future<Map<String, dynamic>?> _send(
    String path,
    Duration timeout, {
    Map<String, Object>? body,
    AiCancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    final request = http.AbortableRequest(
      body == null ? 'GET' : 'POST',
      Uri.http(ollamaHost, path),
      abortTrigger: cancel?.whenCancelled,
    );
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request))
          .timeout(timeout);
    } on http.RequestAbortedException {
      throw const AiCancelledException();
    } catch (e) {
      throw AiServiceException(
        '$e\n\nMake sure Ollama is installed and running on $ollamaHost',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AiServiceException(
        'Failed to get AI response (${response.statusCode}). Make sure Ollama is running with the $_model model.\n${response.body}',
      );
    }
    final Object? data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    return data is Map<String, dynamic> ? data : null;
  }
}
