import 'package:fide/constants/core_constants.dart';
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
  Future<List<String>> search(String text, {required int limit}) async => [
    for (final MapEntry(key: path, value: content) in files.entries)
      for (final (index, line) in content.split('\n').indexed)
        if (line.contains(text)) '$path:${index + 1}: $line',
  ];

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
    final skill = agent
        .skillsFor(edits: true, fixes: [QuickFix.makeConstants])
        .singleWhere((skill) => skill.name == 'run_quick_fix');

    expect(
      await skill.run({'name': 'makeConstants'}),
      'Made constants of 3 strings in 1 files',
    );
    expect(ran, [QuickFix.makeConstants]);
    expect(() => skill.run({'name': 'rewriteAll'}), throwsFormatException);
    // Only the fixes offered run
    expect(
      () => skill.run({'name': QuickFix.upgradePackages.name}),
      throwsFormatException,
    );
    // None without a request naming one, nor when answering, nor when
    // the caller runs none
    List<String> names({required bool edits}) => [
      for (final skill in agent.skillsFor(
        edits: edits,
        fixes: edits ? const [] : QuickFix.values,
      ))
        skill.name,
    ];
    expect(names(edits: true), isNot(contains('run_quick_fix')));
    expect(names(edits: false), isNot(contains('run_quick_fix')));
    expect(
      agentOf(FakeChatModel())
          .skillsFor(edits: true, fixes: QuickFix.values)
          .map((s) => s.name),
      isNot(contains('run_quick_fix')),
    );
  });

  test('reads a long file in parts, saying how to read on', () async {
    final lines = [
      for (var line = 1; line <= 2000; line++) 'final value$line = $line;',
    ];
    store.files['lib/long.dart'] = lines.join('\n');
    final agent = agentOf(FakeChatModel());

    final first = await agent.readFile('lib/long.dart');
    final shownLines = first.split('\n').length - 1;
    expect(first, startsWith('final value1 = 1;\n'));
    expect(first.length, lessThan(AppMetric.aiReadFileChars + 100));
    expect(first, contains('start_line ${shownLines + 1}'));

    final next = await agent.readFile(
      'lib/long.dart',
      startLine: shownLines + 1,
    );
    expect(next, startsWith('final value${shownLines + 1} = '));
    // A file that fits comes whole, exactly, for replace_in_file
    expect(await agent.readFile('lib/main.dart'), 'void main() { print(1) }');
  });

  test('finds code with search', () async {
    final found = await agentOf(FakeChatModel()).search('print');

    expect(found, 'lib/main.dart:1: void main() { print(1) }');
    expect(
      await agentOf(FakeChatModel()).search('missing'),
      'No match for "missing".',
    );
  });

  test('tool results name the call they answer', () async {
    final model = FakeChatModel(
      chatReplies: [
        {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'id': 'call_1',
              'function': {
                'name': 'read_file',
                'arguments': {'path': 'lib/main.dart'},
              },
            },
          ],
        },
        answer('done'),
      ],
    );

    await agentOf(model).edit('look', const []);

    expect(toolResults(model).single['tool_call_id'], 'call_1');
  });

  test(
    'drops earlier tool output once the conversation outgrows the budget',
    () async {
      final big = 'x' * (AppMetric.aiDroppableOutputChars * 10);
      store.files['lib/big.dart'] = big;
      final model = FakeChatModel(
        contextBudget: AppMetric.aiDroppableOutputChars,
        chatReplies: [
          toolCall('read_file', {'path': 'lib/big.dart'}),
          toolCall('write_file', {'path': 'lib/copy.dart', 'content': big}),
          toolCall('check_build', {}),
          answer('Copied.'),
        ],
      );

      await agentOf(model).edit('copy big', const []);

      // The latest reply's call keeps its output
      final second = model.chats[1];
      expect(second.last['content'], big);
      // The step after drops it
      final third = model.chats[2];
      final read = third.firstWhere((m) => m['role'] == 'tool');
      expect(read['content'], contains('call read_file again'));
      // and the step after the write drops the content it wrote
      final write = model.chats[3].firstWhere(
        (m) =>
            m['role'] == 'assistant' && '${m['tool_calls']}'.contains('write'),
      );
      final arguments =
          (write['tool_calls'] as List).single['function']['arguments'] as Map;
      expect(arguments['content'], '(${big.length} characters)');
      expect(arguments['path'], 'lib/copy.dart');
      // Without a budget, the conversation stays whole
      final unbounded = FakeChatModel(
        chatReplies: [
          toolCall('read_file', {'path': 'lib/big.dart'}),
          answer('Read.'),
        ],
      );
      await agentOf(unbounded).edit('read big', const []);
      expect(toolResults(unbounded).single['content'], big);
    },
  );

  test(
    'answers a question reading the code, with no tool that writes',
    () async {
      final model = FakeChatModel(chatReplies: [answer('4')]);

      expect(await agentOf(model).answer('2+2=', const []), '4');

      expect(model.toolNames.single, ['list_files', 'search', 'read_file']);
      expect(model.chats.single.first['content'], contains('never change'));
      expect(written, isEmpty);
    },
  );

  test('offers a whole-project fix only when the request names it', () async {
    final model = FakeChatModel(
      chatReplies: [answer('Done.'), answer('Done.')],
    );
    final agent = CodeEditAgent(
      model,
      files: store,
      hooks: CodeEditHooks(
        onStep: (_) {},
        onFileWritten: (_) async {},
        checkBuild: () async => '',
        runQuickFix: (_) async => 'Done.',
      ),
    );

    await agent.edit('localize the strings of main', const []);
    await agent.edit('fix the overflow in main', const []);

    expect(model.toolNames.first, contains('run_quick_fix'));
    expect(model.chats.first.first['content'], contains('Localize strings'));
    expect(model.toolNames.last, isNot(contains('run_quick_fix')));
    expect(model.toolNames.last, contains('replace_in_file'));
  });

  test('every tool takes a parameter, so no call is left unclosed', () {
    // qwen3-coder can leave a call with no parameter unclosed, which
    // Ollama then fails to read
    for (final skill in agentOf(FakeChatModel()).skillsFor(edits: true)) {
      final parameters = skill.toTool()['function']['parameters'] as Map;
      expect(parameters['required'], isNotEmpty, reason: skill.name);
    }
  });

  test('a call repeated with nothing changed is told, then stopped', () async {
    var checks = 0;
    final model = FakeChatModel(
      chatReplies: [
        for (var i = 0; i < 4; i++) toolCall('check_build', {'changes': 'x'}),
        answer('never reached'),
      ],
    );
    final agent = CodeEditAgent(
      model,
      files: store,
      hooks: CodeEditHooks(
        onStep: (_) {},
        onFileWritten: (_) async {},
        checkBuild: () async {
          checks++;
          return '';
        },
      ),
    );

    final summary = await agent.edit('fix main', const []);

    // Checked once: the repeats get the earlier result, with a note
    expect(checks, 1);
    expect(toolResults(model)[1]['content'], contains('nothing changed'));
    expect(summary, startsWith('Stopped'));
    expect(model.chats, hasLength(1 + AppMetric.aiMaxRepeatedCalls));
  });

  test('a change in between makes the same call run again', () async {
    var checks = 0;
    final model = FakeChatModel(
      chatReplies: [
        toolCall('check_build', {'changes': 'first'}),
        toolCall('replace_in_file', {
          'path': 'lib/main.dart',
          'old_text': 'print(1)',
          'new_text': 'print(1);',
        }),
        toolCall('check_build', {'changes': 'second'}),
        answer('Done.'),
      ],
    );
    final agent = CodeEditAgent(
      model,
      files: store,
      hooks: CodeEditHooks(
        onStep: (_) {},
        onFileWritten: (_) async {},
        checkBuild: () async {
          checks++;
          return '';
        },
      ),
    );

    expect(await agent.edit('fix main', const []), 'Done.');
    expect(checks, 2);
  });
}
