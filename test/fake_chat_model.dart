import 'package:fide/services/chat_model.dart';

/// A [ChatModel] answering from a script instead of Ollama, recording
/// what it was sent.
class FakeChatModel implements ChatModel {
  /// Creates a model answering every prompt with [answer] and each chat
  /// request with the next of [chatReplies].
  FakeChatModel({
    String Function(String prompt)? answer,
    List<Map<String, dynamic>>? chatReplies,
  }) : _answer = answer ?? ((_) => ''),
       _chatReplies = chatReplies ?? [];

  final String Function(String prompt) _answer;
  final List<Map<String, dynamic>> _chatReplies;

  /// The prompts sent to [generate], in order.
  final List<String> prompts = [];

  /// Whether each [generate] or [chat] request let the model think.
  final List<bool> thinks = [];

  /// The timeout of each [generate] request.
  final List<Duration> timeouts = [];

  /// The messages of each [chat] request, as sent.
  final List<List<Map<String, dynamic>>> chats = [];

  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    prompts.add(prompt);
    thinks.add(think);
    timeouts.add(timeout);
    return _answer(prompt);
  }

  @override
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    chats.add(List.of(messages));
    thinks.add(think);
    return _chatReplies.removeAt(0);
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
