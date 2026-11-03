import 'package:fide/models/quick_fix.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_edit_agent.dart';
import 'package:fide/services/project_file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fake_chat_model.dart';

/// A project held in memory, keyed by project-relative path, keeping the
/// real store's path guard.
class _MemoryFileStore extends ProjectFileStore {
  _MemoryFileStore(this.files) : super(rootPath);

  /// Root every path resolves under.
  static const String rootPath = '/project';

  /// The files' content by relative path.
  final Map<String, String> files;

  @override
  Future<List<String>> list(String folder, {required int limit}) async {
    resolve(folder);
    return files.keys.toList()..sort();
  }

  @override
  Future<String> read(String path) async => files[_relative(path)]!;

  @override
  Future<void> write(String path, String content) async {
    files[_relative(path)] = content;
  }

  String _relative(String path) => p.relative(resolve(path), from: rootPath);
}

void main() {
  late _MemoryFileStore store;
  late List<String> written;

  setUp(() {
    store = _MemoryFileStore({'lib/main.dart': 'void main() { print(1) }'});
    written = [];
  });

  /// An agent whose [model] answers, stopped by [cancelToken], whose build
  /// passes.
  CodeEditAgent agentOf(FakeChatModel model, {AiCancelToken? cancelToken}) =>
      CodeEditAgent(
        model,
        files: store,
        cancelToken: cancelToken,
        hooks: CodeEditHooks(
          onStep: (_) {},
          onFileWritten: (path) async => written.add(path),
          checkBuild: () async => '',
        ),
      );

  /// The tool results the agent sent in its last chat request to [model].
  List<Map<String, dynamic>> toolResults(FakeChatModel model) => [
    for (final message in model.chats.last)
      if (message['role'] == 'tool') message,
  ];

  test('edits files through skills and checks the build', () async {
    final model = FakeChatModel(
      chatReplies: [
        toolCall('replace_in_file', {
          'path': 'lib/main.dart',
          'old_text': 'print(1)',
          'new_text': 'print(1);',
        }),
        toolCall('check_build', {}),
        answer('Added the missing semicolon.'),
      ],
    );

    final summary = await agentOf(model).fixBuild("Expected ';'", '');

    expect(summary, 'Added the missing semicolon.');
    expect(store.files['lib/main.dart'], 'void main() { print(1); }');
    expect(written, ['${_MemoryFileStore.rootPath}/lib/main.dart']);
    expect(toolResults(model).last['content'], 'Build succeeded.');
    // Tracing build errors needs the model to think
    expect(model.thinks, everyElement(isTrue));
  });

  test('cancel stops the agent before its next model request', () async {
    final model = FakeChatModel(
      chatReplies: [toolCall('check_build', {}), answer('never sent')],
    );
    late CodeEditAgent agent;
    agent = CodeEditAgent(
      model,
      files: store,
      hooks: CodeEditHooks(
        onStep: (_) {},
        onFileWritten: (_) async {},
        checkBuild: () async {
          agent.cancel();
          return '';
        },
      ),
    );

    await expectLater(
      agent.fixBuild("Expected ';'", ''),
      throwsA(isA<AiCancelledException>()),
    );
    expect(model.chats, hasLength(1));
  });

  test('a cancelled token given to the agent stops it', () async {
    final model = FakeChatModel(chatReplies: [answer('never sent')]);
    final agent = agentOf(model, cancelToken: AiCancelToken()..cancel());

    await expectLater(
      agent.edit('fix it', const []),
      throwsA(isA<AiCancelledException>()),
    );
    expect(model.chats, isEmpty);
  });

  test(
    'makes a requested change in the files, with the chat as context',
    () async {
      final model = FakeChatModel(
        chatReplies: [
          toolCall('replace_in_file', {
            'path': 'lib/main.dart',
            'old_text': 'print(1)',
            'new_text': 'print(2);',
          }),
          answer('Changed lib/main.dart.'),
        ],
      );

      final summary = await agentOf(model).edit('fix 1', [
        {'role': 'user', 'content': 'D.R.Y. review'},
        {'role': 'assistant', 'content': '1. main prints the wrong value'},
      ]);

      expect(summary, 'Changed lib/main.dart.');
      expect(store.files['lib/main.dart'], 'void main() { print(2); }');
      final sent = model.chats.last;
      expect(
        [for (final m in sent) m['role']],
        ['system', 'user', 'assistant', 'user', 'assistant', 'tool'],
      );
      expect(sent[3]['content'], 'fix 1');
    },
  );

  test('refuses paths outside the project', () async {
    final model = FakeChatModel(
      chatReplies: [
        toolCall('write_file', {'path': '../escape.dart', 'content': ''}),
        answer('done'),
      ],
    );

    await agentOf(model).fixBuild('error', '');

    expect(
      toolResults(model).single['content'],
      contains('outside the project'),
    );
    expect(written, isEmpty);
    expect(store.files.keys, ['lib/main.dart']);
  });

  test('lists and reads project files, writing new ones', () async {
    final model = FakeChatModel(
      chatReplies: [
        toolCall('list_files', {'path': '.'}),
        toolCall('read_file', {'path': 'lib/main.dart'}),
        toolCall('write_file', {
          'path': 'lib/new.dart',
          'content': 'class A {}',
        }),
        answer('done'),
      ],
    );
    final agent = agentOf(model);

    await agent.edit('add A', const []);

    expect(agent.projectPath, _MemoryFileStore.rootPath);
    expect(
      [for (final result in toolResults(model)) result['content']],
      ['lib/main.dart', 'void main() { print(1) }', 'Saved lib/new.dart.'],
    );
    expect(store.files['lib/new.dart'], 'class A {}');
  });

  test('runs FIDE quick fixes through run_quick_fix', () async {
    final ran = <QuickFix>[];
    final agent = CodeEditAgent(
      FakeChatModel(),
      files: store,
      hooks: CodeEditHooks(
        onStep: (_) {},
        onFileWritten: (_) async {},
        checkBuild: () async => '',
        runQuickFix: (fix) async {
          ran.add(fix);
          return 'Made constants of 3 strings in 1 files';
        },
      ),
    );
    final skill = agent.skills.singleWhere(
      (skill) => skill.name == 'run_quick_fix',
    );

    expect(
      await skill.run({'name': 'makeConstants'}),
      'Made constants of 3 strings in 1 files',
    );
    expect(ran, [QuickFix.makeConstants]);
    expect(() => skill.run({'name': 'rewriteAll'}), throwsFormatException);
    expect(
      agentOf(FakeChatModel()).skills.map((skill) => skill.name),
      isNot(contains('run_quick_fix')),
    );
  });
}
