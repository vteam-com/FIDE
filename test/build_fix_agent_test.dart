import 'dart:convert';
import 'dart:io';

import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/build_fix_agent.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

/// An SDK whose versions can't be detected, so no tool runs.
class _NoSdk extends FlutterSdk {
  const _NoSdk();

  @override
  Future<({String? flutter, String? dart})?> versions() async => null;
}

/// An Ollama chat reply calling [name] with [arguments].
http.Response _toolCall(String name, Map<String, String> arguments) =>
    http.Response(
      jsonEncode({
        'message': {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'function': {'name': name, 'arguments': arguments},
            },
          ],
        },
      }),
      HttpStatus.ok,
    );

/// An Ollama chat reply with [content] and no tool calls.
http.Response _answer(String content) => http.Response(
  jsonEncode({
    'message': {'role': 'assistant', 'content': content},
  }),
  HttpStatus.ok,
);

void main() {
  late Directory project;
  late List<String> written;
  late List<Map<String, dynamic>> toolResults;

  setUp(() {
    project = Directory.systemTemp.createTempSync('build_fix_agent');
    File(p.join(project.path, 'lib', 'main.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() { print(1) }');
    written = [];
    toolResults = [];
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// An agent whose model sends [replies] in order and whose build passes.
  BuildFixAgent agentReplying(List<http.Response> replies) {
    final client = MockClient((request) async {
      // Model lookups: no model listed, so requests keep the default
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'models': []}), HttpStatus.ok);
      }
      final messages = jsonDecode(request.body)['messages'] as List;
      toolResults = [
        for (final message in messages)
          if (message['role'] == 'tool') message as Map<String, dynamic>,
      ];
      return replies.removeAt(0);
    });
    return BuildFixAgent(
      AIService(const _NoSdk(), client),
      projectPath: project.path,
      hooks: BuildFixHooks(
        onStep: (_) {},
        onFileWritten: (path) async => written.add(path),
        checkBuild: () async => '',
      ),
    );
  }

  test('edits files through skills and checks the build', () async {
    final agent = agentReplying([
      _toolCall('replace_in_file', {
        'path': 'lib/main.dart',
        'old_text': 'print(1)',
        'new_text': 'print(1);',
      }),
      _toolCall('check_build', {}),
      _answer('Added the missing semicolon.'),
    ]);

    final summary = await agent.run("Expected ';'", '');

    expect(summary, 'Added the missing semicolon.');
    expect(
      File(p.join(project.path, 'lib', 'main.dart')).readAsStringSync(),
      'void main() { print(1); }',
    );
    expect(written, [p.join(project.path, 'lib', 'main.dart')]);
    expect(toolResults.last['content'], 'Build succeeded.');
  });

  test('refuses paths outside the project', () async {
    final agent = agentReplying([
      _toolCall('write_file', {'path': '../escape.dart', 'content': ''}),
      _answer('done'),
    ]);

    await agent.run('error', '');

    expect(toolResults.single['content'], contains('outside the project'));
    expect(written, isEmpty);
  });

  test('lists project files without build output', () async {
    File(p.join(project.path, 'build', 'out.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('');

    final agent = agentReplying([]);

    expect(await agent.listFiles('.'), p.join('lib', 'main.dart'));
  });
}
