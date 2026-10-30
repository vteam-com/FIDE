part of 'ai_panel.dart';

/// One message in the AI panel's chat.
class ChatMessage {
  /// The message text, Markdown for model replies.
  final String content;

  /// Whether the user wrote it rather than the model.
  final bool isUser;

  /// Whether it only reports progress (a tool step, a notice), so it is
  /// left out of the history sent back to the model.
  final bool isProgress;

  /// When it was added.
  final DateTime? timestamp;

  /// Creates a chat message.
  ChatMessage({
    required this.content,
    required this.isUser,
    this.isProgress = false,
    this.timestamp,
  });
}
