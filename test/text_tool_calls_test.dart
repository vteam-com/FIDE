import 'package:fide/models/text_tool_calls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextToolCalls', () {
    test('reads XML calls, keeping the whitespace of their values', () {
      const content =
          'I will fix it.\n<tool_call>\n<function=replace_in_file>\n'
          '<parameter=path>\nlib/a.dart\n</parameter>\n'
          '<parameter=old_text>\n  int x;\n\n</parameter>\n'
          '<parameter=new_text>\n</parameter>\n'
          '</function>\n</tool_call>';

      expect(TextToolCalls.parse(content), [
        {
          'function': {
            'name': 'replace_in_file',
            'arguments': {
              'path': 'lib/a.dart',
              'old_text': '  int x;\n',
              'new_text': '',
            },
          },
        },
      ]);
      expect(TextToolCalls.textBefore(content), 'I will fix it.');
    });

    test('reads JSON calls between tool_call tags', () {
      expect(
        TextToolCalls.parse(
          '<tool_call>{"name": "read_file", '
          '"arguments": {"path": "lib/a.dart"}}</tool_call>',
        ),
        [
          {
            'function': {
              'name': 'read_file',
              'arguments': {'path': 'lib/a.dart'},
            },
          },
        ],
      );
    });

    test('finds no call in plain text or malformed JSON', () {
      const plain = 'Removed the unused class.';

      expect(TextToolCalls.parse(plain), isEmpty);
      expect(TextToolCalls.parse('<tool_call>{"name": }</tool_call>'), isEmpty);
      expect(TextToolCalls.textBefore(plain), plain);
    });
  });
}
