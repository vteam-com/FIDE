import 'dart:async';

part 'chat_model.ai_cancel_token.dart';
part 'chat_model.ai_cancelled_exception.dart';
part 'chat_model.ai_service_exception.dart';

/// Receives the text of a reply as it streams in: all of it so far.
typedef ReplyText = void Function(String textSoFar);

/// A language model answering prompts and chats with tools, such as the
/// local Ollama model: what FIDE's AI features depend on, so they can be
/// tested with a fake model.
///
/// Chats use Ollama's message format, which the other models translate:
/// `role` (`system`, `user`, `assistant` or `tool`) and `content`; an
/// assistant message lists the calls it wants run in `tool_calls`
/// (`{'id': …, 'function': {'name': …, 'arguments': {…}}}`), and a `tool`
/// message answers one call, naming it by `tool_name` and
/// `tool_call_id`. A model may keep what it needs to replay its own
/// replies in other keys of the messages it returns.
///
/// Failed requests throw an [AiServiceException]; requests stopped through
/// their [AiCancelToken] throw an [AiCancelledException].
abstract interface class ChatModel {
  /// Name of the model answering, for the AI panel.
  String get name;

  /// Whether the model can call tools, which editing files needs.
  bool get supportsTools;

  /// Tokens an agent's conversation may reach before it drops the output
  /// of earlier tool calls; null when it needn't, as on a model with a
  /// large context that reuses a cached prefix.
  int? get contextBudget;

  /// Gets the model ready to answer at once, as loading a local model in
  /// memory does; failures are left to the requests that follow.
  Future<void> warmUp();

  /// Sends [prompt] and returns the model's response text, which may be
  /// empty, failing after [timeout]; [think] lets a thinking model reason
  /// first, [cancel] stops the request and [onText] receives the reply as
  /// it streams in.
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  });

  /// Sends the conversation [messages] with the [tools] the model may call
  /// and returns the model's reply message, whose `tool_calls` list the
  /// calls it wants run; [think] lets a thinking model reason first,
  /// [cancel] stops the request and [onText] receives the reply's text as
  /// it streams in.
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
    ReplyText? onText,
  });
}
