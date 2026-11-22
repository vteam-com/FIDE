import 'package:fide/constants/constants.dart';
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

  test('the request shows the recent messages as the style, then the '
      'digest of the changes', () async {
    String? asked;
    final writer = CommitMessageWriter(
      FakeChatModel(
        answer: (prompt) {
          asked = prompt;
          return 'Git panel: commit messages in the project\'s style';
        },
      ),
    );

    await writer.write(
      'diff --git a/README.md b/README.md\n+Move moves a file\n',
      examples: ['Overview: the CocoaPods check joins its card'],
    );

    expect(
      asked,
      contains(
        "style of this project's recent commit messages:\n"
        '- Overview: the CocoaPods check joins its card\n',
      ),
    );
    expect(asked, endsWith('Documentation added:\nMove moves a file'));
  });

  test('the style takes as many recent messages as its budget holds', () {
    final example = 'x' * (AppMetric.aiCommitStyleChars ~/ 2);

    final prompt = CommitMessageWriter.promptFor(
      'diff',
      examples: [example, example, example],
    );

    expect(RegExp('- $example').allMatches(prompt), hasLength(1));
  });
}
