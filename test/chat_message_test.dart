import 'package:fide/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage step(String text) =>
      ChatMessage(content: text, isUser: false, isProgress: true);

  test('shows a run of steps as one entry, a repeated step counted', () {
    final shown = ChatMessage.compacted([
      ChatMessage(content: 'Rename it', isUser: true),
      step('🔧 read_file lib/a.dart'),
      step('🔧 check_build'),
      step('🔧 check_build'),
      step('🔧 check_build'),
      step('🔧 read_file lib/a.dart'),
      ChatMessage(content: 'Renamed.', isUser: false),
      step('🔧 search a'),
    ]);

    expect(
      [for (final message in shown) message.content],
      [
        'Rename it',
        '🔧 read_file lib/a.dart\n🔧 check_build ×3\n🔧 read_file lib/a.dart',
        'Renamed.',
        '🔧 search a',
      ],
    );
    expect(shown[1].isProgress, isTrue);
    expect(shown[2].isProgress, isFalse);
  });
}
