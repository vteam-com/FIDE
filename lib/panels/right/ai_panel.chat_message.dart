part of 'ai_panel.dart';

/// Represents `ChatMessage`.
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime? timestamp;

  ChatMessage({required this.content, required this.isUser, this.timestamp});
}
