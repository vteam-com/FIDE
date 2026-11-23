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

  group('the start of the message follows the recent messages', () {
    const area = 'Start with the part of the app they change';
    const verb = 'Start with a verb in the imperative';

    test('an area and a colon when most of them start so', () {
      final prompt = CommitMessageWriter.promptFor(
        'diff',
        examples: ['Git panel: one row per move', 'Editor: wrap lines', 'x'],
      );

      expect(prompt, contains(area));
      expect(prompt, isNot(contains(verb)));
    });

    test('a verb when most of them have no area', () {
      final prompt = CommitMessageWriter.promptFor(
        'diff',
        examples: ['Pin Flutter 3.50.0', 'Build the web app as Wasm', 'a: b'],
      );

      expect(prompt, contains(verb));
      expect(prompt, isNot(contains(area)));
    });

    test('an area and a colon when there are none', () {
      expect(CommitMessageWriter.promptFor('diff'), contains(area));
    });
  });
}
