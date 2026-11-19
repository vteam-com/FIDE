/// The message format of chats with a model, Ollama's: the keys of a
/// message and of the tool calls it lists, its roles, and builders.
class ModelMessage {
  /// Not instantiated: a namespace for the format.
  const ModelMessage._();

  /// Key of who wrote a message: one of the roles below.
  static const String roleKey = 'role';

  /// Key of a message's text.
  static const String contentKey = 'content';

  /// Key of the calls an assistant message wants run.
  static const String toolCallsKey = 'tool_calls';

  /// Key of the function a tool call makes or a tool definition offers.
  static const String functionKey = 'function';

  /// Key of a function's name.
  static const String nameKey = 'name';

  /// Key of the arguments of a function call.
  static const String argumentsKey = 'arguments';

  /// Key of a tool call's id, which the tool message answering it repeats.
  static const String idKey = 'id';

  /// Key of the tool a tool message answers.
  static const String toolNameKey = 'tool_name';

  /// Key of the call a tool message answers.
  static const String toolCallIdKey = 'tool_call_id';

  /// Role of the instructions starting a chat.
  static const String systemRole = 'system';

  /// Role of what the user says.
  static const String userRole = 'user';

  /// Role of the model's replies.
  static const String assistantRole = 'assistant';

  /// Role of a tool call's result.
  static const String toolRole = 'tool';

  /// A message from [role] saying [content].
  static Map<String, String> of(String role, String content) => {
    roleKey: role,
    contentKey: content,
  };

  /// What the user says: [content].
  static Map<String, String> user(String content) => of(userRole, content);

  /// A tool call running the function [name] with [arguments].
  static Map<String, dynamic> toolCall(
    String name,
    Map<String, dynamic> arguments,
  ) => {
    functionKey: {nameKey: name, argumentsKey: arguments},
  };
}
