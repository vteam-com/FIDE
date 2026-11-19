/// One message in the AI panel's chat.
class ChatMessage {
  /// Creates a chat message.
  ChatMessage({
    required this.content,
    required this.isUser,
    this.isProgress = false,
    this.timestamp,
  });

  /// The message text, Markdown for model replies.
  final String content;

  /// Whether it only reports progress (a tool step, a notice), so it is
  /// left out of the history sent back to the model.
  final bool isProgress;

  /// Whether the user wrote it rather than the model.
  final bool isUser;

  /// When it was added.
  final DateTime? timestamp;

  /// [messages] as the transcript shows them: each run of progress
  /// messages as one, a line each, so the steps of a reply read as a
  /// short list rather than a screen of entries; a step repeated in a row
  /// shows once with its count, such as "🔧 check_build ×3".
  static List<ChatMessage> compacted(List<ChatMessage> messages) {
    final shown = <ChatMessage>[];
    final steps = <({String text, int count})>[];
    DateTime? lastStep;
    void endSteps() {
      if (steps.isEmpty) return;
      shown.add(
        ChatMessage(
          content: [
            for (final (:text, :count) in steps)
              count > 1 ? '$text ×$count' : text,
          ].join('\n'),
          isUser: false,
          isProgress: true,
          timestamp: lastStep,
        ),
      );
      steps.clear();
    }

    for (final message in messages) {
      if (!message.isProgress) {
        endSteps();
        shown.add(message);
        continue;
      }
      lastStep = message.timestamp;
      final last = steps.lastOrNull;
      if (last != null && last.text == message.content) {
        steps.last = (text: last.text, count: last.count + 1);
      } else {
        steps.add((text: message.content, count: 1));
      }
    }
    endSteps();
    return shown;
  }
}
