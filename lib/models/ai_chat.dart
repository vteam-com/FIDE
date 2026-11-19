import 'package:fide/models/ai_action.dart';
import 'package:fide/models/chat_message.dart';

/// The AI panel's conversation, kept while the panel is hidden: its
/// messages, the action new prompts use, whether a reply or task is
/// pending, and the reply streaming in meanwhile.
class AiChat {
  /// Creates a conversation.
  const AiChat({
    this.messages = const [],
    this.action = AiAction.ask,
    this.isBusy = false,
    this.draft = '',
  });

  /// What new prompts ask the model to do.
  final AiAction action;

  /// The text of the model's reply as it streams in, empty while none
  /// does.
  final String draft;

  /// Whether a reply or task is pending, which disables sending.
  final bool isBusy;

  /// The messages, oldest first.
  final List<ChatMessage> messages;

  /// A copy with the given fields replaced.
  AiChat copyWith({
    List<ChatMessage>? messages,
    AiAction? action,
    bool? isBusy,
    String? draft,
  }) => AiChat(
    messages: messages ?? this.messages,
    action: action ?? this.action,
    isBusy: isBusy ?? this.isBusy,
    draft: draft ?? this.draft,
  );
}
