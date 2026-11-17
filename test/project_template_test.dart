import 'package:fide/services/project_template.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

void main() {
  /// The template asked for a project whose model replies [reply].
  ProjectTemplate templateReplying(String reply) =>
      ProjectTemplate(FakeChatModel(answer: (_) => reply));

  test('falls back to a basic main.dart', () async {
    final files = await templateReplying('no code here')
        .generate('demo', 'A demo');

    expect(files['lib/main.dart'], contains('void main()'));
    expect(files, isNot(contains('pubspec.yaml')));
    expect(files['README.md'], startsWith('# demo\n\nA demo'));
  });

  test('takes main.dart from the first code block that has it', () async {
    final files = await templateReplying(
      'Here it is:\n```dart\nvoid main() => runApp(const App());\n```',
    ).generate('demo', 'A demo');

    expect(files['lib/main.dart'], 'void main() => runApp(const App());');
  });

  test('quotes the description in the basic app', () async {
    final files = await templateReplying('no code here')
        .generate('demo', 'It\'s \$5\nper "month"');

    expect(files['lib/main.dart'], contains(r"""'It\'s \$5\nper "month"'"""));
  });
}
