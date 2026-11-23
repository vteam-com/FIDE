import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/models/model_message.dart';
import 'package:fide/models/text_tool_calls.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/model_http.dart';
import 'package:http/http.dart' as http;

/// The local Ollama model as a [ChatModel]: picks the model among the
/// downloaded ones and streams prompts and chats through Ollama's HTTP
/// API.
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

  /// Told the model when Ollama couldn't read its tool call, as when
  /// qwen3-coder leaves out `</function>`: the same request would write
  /// the same broken call.
  static const Map<String, String> _unreadableCall = {
    ModelMessage.roleKey: ModelMessage.userRole,
    ModelMessage.contentKey:
        'Your last tool call could not be read. Call the tool again, '
        'writing the whole call: every <parameter=…> closed by '
        '</parameter>, then </function> before </tool_call>.',
  };

  final ModelHttp _http;

  String _preferred;

  late String _model = _preferred;

  /// The models downloaded, as the last [resolveModel] listed them.
  Set<String> _downloaded = const {};
  bool _isModelResolved = false;
  bool _supportsTools = true;
  bool _supportsThinking = false;

  /// The warm-up in flight, so the panel asking again joins it.
  Future<void>? _warmingUp;

  /// Creates a client sending requests through [client] to the
  /// [preferred] model when it is downloaded, [LocalModel.defaultModel]
  /// by default.
  OllamaClient(http.Client client, {String? preferred})
    : _preferred = preferred ?? LocalModel.defaultModel.tag,
      _http = ModelHttp(
        client,
        service: 'Ollama',
        unreachableHint:
            'Make sure Ollama is installed and running on $ollamaHost',
        slowHint:
            ': the model may be too large for the memory free, or the '
            'prompt too long',
      );

  /// The model [resolveModel] picks first when it is downloaded: the
  /// one picked in the AI panel, or another one measured against it.
  String get preferred => _preferred;

  /// Makes [tag] the [preferred] model; the next request resolves the
  /// model again.
  set preferred(String tag) {
    if (tag == _preferred) return;
    _preferred = tag;
    _model = tag;
    _isModelResolved = false;
  }

  /// The models downloaded, by tag, as the last [resolveModel] listed
  /// them; empty until it ran.
  Set<String> get downloaded => _downloaded;

  /// Whether [model] stands in for [preferred], which isn't downloaded
  /// or can't call tools.
  bool get isFallbackModel => !_isPreferred(_model);

  /// The model requests go to; see [resolveModel].
  String get model => _model;

  @override
  String get name => _model;

  @override
  bool get supportsTools => _supportsTools;

  @override
  int? get contextBudget => AppMetric.aiContextBudgetTokens;

  /// Picks the model requests go to among the downloaded ones and returns
  /// it, or null when none is downloaded: [preferred] first,
  /// then any model that can call tools, then any model.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached.
  Future<String?> resolveModel({AiCancelToken? cancel}) async {
    final tags = await _http.json(
      Uri.http(ollamaHost, _tagsPath),
      AppDuration.aiSuggestionTimeout,
      cancel: cancel,
    );
    final listed = tags?['models'];
    final names = [
      if (listed is List)
        for (final entry in listed)
          if (entry is Map && entry['name'] is String) entry['name'] as String,
    ];
    _downloaded = names.toSet();
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

  /// Loads the model in memory, as a request with no prompt does, so the
  /// first question doesn't wait for it: a large model takes seconds to
  /// load. A model already loaded answers at once.
  @override
  Future<void> warmUp() =>
      _warmingUp ??= _loadModel().whenComplete(() => _warmingUp = null);

  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  }) async {
    final reply = await _stream(
      _generatePath,
      (_) => {'prompt': prompt},
      timeout,
      think: think,
      cancel: cancel,
      onText: onText,
    );
    return reply.text;
  }

  @override
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  }) async {
    final reply = await _stream(
      _chatPath,
      // The same request writes the same broken call: a retry says what
      // went wrong
      (retry) => {
        'messages': retry == 0 ? messages : [...messages, _unreadableCall],
        'tools': tools,
      },
      AppDuration.aiToolStepTimeout,
      think: think,
      cancel: cancel,
      onText: onText,
    );
    return _withWrittenCalls({
      ...ModelMessage.of(ModelMessage.assistantRole, reply.text),
      if (reply.toolCalls.isNotEmpty)
        ModelMessage.toolCallsKey: reply.toolCalls,
    });
  }

  /// The capabilities Ollama reports for [name], or null when it doesn't
  /// say, as older Ollama versions report none.
  Future<List<Object?>?> _capabilities(
    String name,
    AiCancelToken? cancel,
  ) async {
    final details = await _http.json(
      Uri.http(ollamaHost, _showPath),
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

  /// Whether [name] is [preferred] under any tag, or the very tag
  /// [preferred] names.
  bool _isPreferred(String name) =>
      name == preferred || name.startsWith('$preferred:');

  /// Sends a request with no prompt, which loads the model; a failure is
  /// left to the requests that follow, which report it.
  Future<void> _loadModel() async {
    try {
      await _stream(
        _generatePath,
        (_) => const {},
        AppDuration.aiGenerateTimeout,
        think: false,
        cancel: null,
        onText: null,
      );
    } on AiServiceException {
      // Reported by the next request
    }
  }

  /// Streams the [body] of each attempt (plus the model name) to Ollama's
  /// [path], resolving the model first when [resolveModel] hasn't, and
  /// returns the reply's text, which [onText] receives as it grows, and
  /// the tool calls it lists. A malformed tool call, which Ollama fails
  /// the request for, is asked for again with the body of the retry.
  ///
  /// A thinking model reasons before answering only when [think] is set:
  /// on a local model the hidden reasoning costs most of the time and
  /// energy of a request, so only tasks needing judgment ask for it. The
  /// model stays loaded for [AppDuration.aiModelKeepAlive] so the next
  /// request doesn't reload it, with one [AppMetric.aiContextTokens]
  /// context window for every request.
  Future<({String text, List<Object?> toolCalls})> _stream(
    String path,
    Map<String, Object> Function(int retry) body,
    Duration timeout, {
    required bool think,
    required AiCancelToken? cancel,
    required ReplyText? onText,
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
    return ModelHttp.retrying(cancel: cancel, (retry) async {
      final text = StringBuffer();
      final toolCalls = <Object?>[];
      await for (final chunk in _http.jsonLines(
        Uri.http(ollamaHost, path),
        timeout,
        body: {
          'model': _model,
          'stream': true,
          'keep_alive': AppDuration.aiModelKeepAlive.inSeconds,
          'options': {'num_ctx': AppMetric.aiContextTokens},
          if (_supportsThinking) 'think': think,
          ...body(retry),
        },
        cancel: cancel,
      )) {
        final message = chunk['message'];
        final words = message is Map
            ? message[ModelMessage.contentKey]
            : chunk['response'];
        if (words is String && words.isNotEmpty) {
          text.write(words);
          onText?.call(TextToolCalls.textBefore(text.toString()));
        }
        final calls = message is Map
            ? message[ModelMessage.toolCallsKey]
            : null;
        if (calls is List) toolCalls.addAll(calls);
      }
      return (text: text.toString(), toolCalls: toolCalls);
    });
  }

  /// [reply], with the tool calls the model wrote in its text as its
  /// `tool_calls` when Ollama found none, so they run, and so the history
  /// shows the model proper calls rather than text it would imitate.
  static Map<String, dynamic> _withWrittenCalls(Map<String, dynamic> reply) {
    final calls = reply[ModelMessage.toolCallsKey];
    if (calls is List && calls.isNotEmpty) return reply;
    final content = reply[ModelMessage.contentKey]?.toString() ?? '';
    final written = TextToolCalls.parse(content);
    if (written.isEmpty) return reply;
    return {
      ...reply,
      ModelMessage.contentKey: TextToolCalls.textBefore(content),
      ModelMessage.toolCallsKey: written,
    };
  }
}
