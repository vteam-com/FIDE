import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_template.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

/// An SDK whose versions can't be detected, so no tool runs.
class _NoSdk extends FlutterSdk {
  const _NoSdk() : super(const ProcessRunner());

  @override
  Future<({String? flutter, String? dart})?> versions() async => null;
}

void main() {
  /// The template asked for a project whose model replies [reply].
  ProjectTemplate templateReplying(String reply) =>
      ProjectTemplate(FakeChatModel(answer: (_) => reply), const _NoSdk());

  test('falls back to a basic main.dart', () async {
    final files = await templateReplying('no code here')
        .generate('demo', 'A demo');

    expect(files['lib/main.dart'], contains('void main()'));
    expect(files['pubspec.yaml'], contains('name: demo'));
    expect(files['README.md'], startsWith('# demo\n\nA demo'));
  });

  test('takes main.dart from the first code block that has it', () async {
    final files = await templateReplying(
      'Here it is:\n```dart\nvoid main() => runApp(const App());\n```',
    ).generate('demo', 'A demo');

    expect(files['lib/main.dart'], 'void main() => runApp(const App());');
  });

  test('quotes the description in pubspec.yaml and the basic app', () async {
    final files = await templateReplying('no code here')
        .generate('demo', 'It\'s \$5\nper "month"');

    expect(
      files['pubspec.yaml'],
      contains(r'''description: "It's $5 per \"month\""'''),
    );
    expect(files['lib/main.dart'], contains(r'''"It's \$5\nper \"month\""'''));
  });
}
