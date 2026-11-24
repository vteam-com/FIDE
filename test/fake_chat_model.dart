import 'package:fide/services/chat_model.dart';

/// A [ChatModel] answering from a script instead of a real model,
/// recording what it was sent.
class FakeChatModel implements ChatModel {
  /// Creates a model answering every prompt with [answer] and each chat
  /// request with the next of [chatReplies]; it calls tools unless
  /// [supportsTools] is false and keeps conversations within
  /// [contextBudget] tokens when given.
  FakeChatModel({
    String Function(String prompt)? answer,
    List<Map<String, dynamic>>? chatReplies,
    this.supportsTools = true,
    this.contextBudget,
  }) : _answer = answer ?? ((_) => ''),
       _chatReplies = chatReplies ?? [];

  final String Function(String prompt) _answer;
  final List<Map<String, dynamic>> _chatReplies;

  @override
  final bool supportsTools;

  @override
  final int? contextBudget;

  @override
  String get name => 'fake';

  /// How many times [warmUp] was called.
  int warmUps = 0;

  /// The prompts sent to [generate], in order.
  final List<String> prompts = [];

  /// Whether each [generate] or [chat] request let the model think.
  final List<bool> thinks = [];

  /// The timeout of each [generate] request.
  final List<Duration> timeouts = [];

  /// The messages of each [chat] request, as sent.
  final List<List<Map<String, dynamic>>> chats = [];

  /// The names of the tools each [chat] request offered.
  final List<List<String>> toolNames = [];

  /// The longest reply each [chat] request allowed, null for no cap.
  final List<int?> maxTokens = [];

  @override
  Future<void> warmUp() async => warmUps++;

  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  }) async {
    cancel?.throwIfCancelled();
    prompts.add(prompt);
    thinks.add(think);
    timeouts.add(timeout);
    final reply = _answer(prompt);
    onText?.call(reply);
    return reply;
  }

  @override
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
    int? maxTokens,
  }) async {
    cancel?.throwIfCancelled();
    this.maxTokens.add(maxTokens);
    chats.add([
      for (final message in messages) {...message},
    ]);
    toolNames.add([
      for (final tool in tools) '${(tool['function'] as Map)['name']}',
    ]);
    thinks.add(think);
    final reply = _chatReplies.removeAt(0);
    onText?.call('${reply['content'] ?? ''}');
    return reply;
  }
}

/// A [FakeChatModel] whose answers stream [start], then end as [answer]
/// once [release] completes, as a model still writing.
class StreamingChatModel extends FakeChatModel {
  /// Creates the model streaming [start] of [answer] until [release].
  StreamingChatModel({
    required this.start,
    required String answer,
    required this.release,
  }) : super(answer: (_) => answer);

  /// What the answer begins with, streamed at once.
  final String start;

  /// Completes when the answer may end.
  final Future<void> release;

  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  }) async {
    onText?.call(start);
    await release;
    return super.generate(prompt, timeout, think: think, cancel: cancel);
  }
}

/// A chat reply calling the tool [name] with [arguments].
Map<String, dynamic> toolCall(String name, Map<String, String> arguments) => {
  'role': 'assistant',
  'content': '',
  'tool_calls': [
    {
      'function': {'name': name, 'arguments': arguments},
    },
  ],
};

/// A chat reply with [content] and no tool calls.
Map<String, dynamic> answer(String content) => {
  'role': 'assistant',
  'content': content,
};
