import 'package:fide/services/commit_message_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

void main() {
  test('commit message keeps the first line without quotes', () async {
    final writer = CommitMessageWriter(
      FakeChatModel(answer: (_) => '\n"Add login screen"\nIt adds a screen.'),
    );

    expect(await writer.write('diff'), 'Add login screen');
  });
}
