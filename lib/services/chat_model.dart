import 'dart:async';

part 'chat_model.ai_cancel_token.dart';
part 'chat_model.ai_cancelled_exception.dart';
part 'chat_model.ai_service_exception.dart';
part 'chat_model.model_reply.dart';

/// A language model answering prompts and chats with tools, such as the
/// local Ollama model: what FIDE's AI features depend on, so they can be
/// tested with a fake model.
///
/// Failed requests throw an [AiServiceException]; requests stopped through
/// their [AiCancelToken] throw an [AiCancelledException].
abstract interface class ChatModel {
  /// Sends [prompt] and returns the model's response text, which may be
  /// empty, failing after [timeout]; [think] lets a thinking model reason
  /// first, and [cancel] stops the request.
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
  });

  /// Sends the conversation [messages] with the [tools] the model may call
  /// and returns the model's reply message, whose `tool_calls` list the
  /// calls it wants run; [think] lets a thinking model reason first, and
  /// [cancel] stops the request.
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
  });
}
