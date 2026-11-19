import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/project_file_store.dart';
import 'package:path/path.dart' as p;

part 'code_edit_agent.ai_skill.dart';
part 'code_edit_agent.code_edit_hooks.dart';

/// Changes a project's code by letting the model read and edit its files
/// through skills ([skillsFor]): fixing a broken build ([fixBuild]) or
/// carrying out a request from the chat ([edit]), checking its work for
/// errors; or answers a question, reading the code without changing it
/// ([answer]).
///
/// Every path a skill touches goes through [files], which keeps it inside
/// the project. The conversation stays within the model's
/// [ChatModel.contextBudget], which a local model needs to stay fast.
class CodeEditAgent {
  final ChatModel _model;

  /// Name of the tool running FIDE's whole-project fixes.
  static const String _quickFixName = 'run_quick_fix';

  /// Stops the agent's model requests and skills; see [cancel].
  final AiCancelToken _cancelToken;

  /// The project files the model may list, search, read and edit.
  final ProjectFileStore files;

  /// What the agent calls as it works.
  final CodeEditHooks hooks;

  /// Creates an agent that talks to [_model] and edits [files], stopped by
  /// [cancelToken] as well as by [cancel].
  CodeEditAgent(
    this._model, {
    required this.files,
    required this.hooks,
    AiCancelToken? cancelToken,
  }) : _cancelToken = cancelToken ?? AiCancelToken();

  /// Root of the project the model may read and edit.
  String get projectPath => files.root;

  /// Stops the agent: aborts its model request in flight and runs no
  /// further skill or request, so [edit] or [fixBuild] throws an
  /// [AiCancelledException]. A skill already running finishes first.
  /// Other features' requests are unaffected.
  void cancel() => _cancelToken.cancel();

  /// The tools the model may call: reading the project always, editing it
  /// when [edits], and FIDE's own whole-project [fixes], only those the
  /// request names, when the caller runs them.
  List<AiSkill> skillsFor({
    required bool edits,
    List<QuickFix> fixes = const [],
  }) => [
    ..._readSkills,
    if (edits) ..._editSkills,
    if (edits) ?_quickFixSkill(fixes),
  ];

  /// The tools reading the project.
  late final List<AiSkill> _readSkills = [
    AiSkill(
      name: 'list_files',
      description: 'Lists the files under a project folder, recursively.',
      parameters: {'path': 'Folder relative to the project root, or "."'},
      run: (args) => listFiles(_argument(args, 'path')),
    ),
    AiSkill(
      name: 'search',
      description:
          'Finds the lines of the project files holding a text, whatever '
          'its case, as path:line: text. Faster than reading files to find '
          'where something is.',
      parameters: {'text': 'Text to find, such as a class or method name'},
      run: (args) => search(_argument(args, 'text')),
    ),
    AiSkill(
      name: 'read_file',
      description:
          'Returns the content of a project file; a long one in parts, '
          'saying how to read on.',
      parameters: {'path': 'File relative to the project root'},
      optionalParameters: {
        'start_line': 'First line to return, from 1; the default',
      },
      run: (args) => readFile(
        _argument(args, 'path'),
        startLine: int.tryParse('${args['start_line']}') ?? 1,
      ),
    ),
  ];

  /// The tools changing the project and checking it.
  late final List<AiSkill> _editSkills = [
    AiSkill(
      name: 'replace_in_file',
      description:
          'Replaces text that occurs exactly once in a project file. '
          'Prefer it to write_file for small fixes.',
      parameters: {
        'path': 'File relative to the project root',
        'old_text': 'Exact text to replace, including whitespace',
        'new_text': 'Replacement text',
      },
      run: (args) => replaceInFile(
        _argument(args, 'path'),
        _argument(args, 'old_text'),
        _argument(args, 'new_text'),
      ),
    ),
    AiSkill(
      name: 'write_file',
      description: 'Creates or overwrites a project file with new content.',
      parameters: {
        'path': 'File relative to the project root',
        'content': 'The complete new file content',
      },
      run: (args) =>
          _write(_argument(args, 'path'), _argument(args, 'content')),
    ),
    AiSkill(
      name: 'check_build',
      description:
          'Checks the project for compile errors and returns them, or says '
          'the build succeeded.',
      parameters: const {},
      run: (_) async {
        final errors = await hooks.checkBuild();
        return errors.isEmpty
            ? 'Build succeeded.'
            : errors.truncated(AppMetric.aiBuildErrorChars);
      },
    ),
  ];

  /// The tool running one of FIDE's whole-project [fixes]; null when there
  /// are none or the caller runs none.
  AiSkill? _quickFixSkill(List<QuickFix> fixes) {
    final runQuickFix = hooks.runQuickFix;
    if (runQuickFix == null || fixes.isEmpty) return null;
    return AiSkill(
      name: _quickFixName,
      description:
          'Has FIDE do a whole-project fix itself, faster and safer than '
          'editing files: ${[for (final fix in fixes) '${fix.name} ${fix.purpose}'].join('; ')}. '
          'Returns what it changed and what it left for you.',
      parameters: {'name': 'One of ${fixes.map((fix) => fix.name).join(', ')}'},
      run: (args) {
        final name = _argument(args, 'name');
        final fix = fixes.where((fix) => fix.name == name).firstOrNull;
        if (fix == null) throw FormatException('Unknown quick fix "$name"');
        return runQuickFix(fix);
      },
    );
  }

  /// Files under [folder] (relative to [projectPath]), one relative path
  /// per line, at most [AppMetric.aiMaxListedFiles] of them.
  Future<String> listFiles(String folder) async {
    final listed = await files.list(folder, limit: AppMetric.aiMaxListedFiles);
    return listed.join('\n');
  }

  /// The lines of the project's files holding [text], one `path:line:
  /// text` per line, at most [AppMetric.aiSearchMaxResults] of them.
  Future<String> search(String text) async {
    final found = await files.search(text, limit: AppMetric.aiSearchMaxResults);
    return found.isEmpty ? 'No match for "$text".' : found.join('\n');
  }

  /// The content of [path], whole when it fits in
  /// [AppMetric.aiReadFileChars]; else the lines from [startLine] (from 1)
  /// that fit, cut at a line end, then a note saying how to read on.
  Future<String> readFile(String path, {int startLine = 1}) async {
    final content = await files.read(path);
    if (startLine <= 1 && content.length <= AppMetric.aiReadFileChars) {
      return content;
    }
    final lines = const LineSplitter().convert(content);
    final first = (startLine - 1).clamp(0, lines.length);
    final shown = StringBuffer();
    var end = first;
    while (end < lines.length &&
        (end == first ||
            shown.length + lines[end].length < AppMetric.aiReadFileChars)) {
      shown.writeln(lines[end].truncated(AppMetric.aiReadFileChars));
      end++;
    }
    final more = end < lines.length
        ? ' Call read_file with start_line ${end + 1} to read on.'
        : '';
    return '$shown[Lines ${first + 1} to $end of ${lines.length}.$more]';
  }

  /// Replaces the single occurrence of [oldText] in [path] with [newText].
  ///
  /// Throws a [FormatException] when [oldText] is missing or not unique,
  /// so the model can retry with more context.
  Future<String> replaceInFile(
    String path,
    String oldText,
    String newText,
  ) async {
    final content = await files.read(path);
    final index = content.indexOf(oldText);
    if (oldText.isEmpty || index < 0) {
      throw FormatException('old_text not found in $path');
    }
    if (content.indexOf(oldText, index + oldText.length) >= 0) {
      throw FormatException(
        'old_text occurs more than once in $path; include more lines',
      );
    }
    return _write(
      path,
      content.replaceRange(index, index + oldText.length, newText),
    );
  }

  /// Answers the user's [question], with the earlier chat [history]
  /// (`role`/`content` messages) for context, reading the project's code
  /// when the question is about it, and never changing it: the model gets
  /// no tool that writes, builds or runs a fix.
  ///
  /// Throws an [AiServiceException] when the model can't be reached, and
  /// an [AiCancelledException] after [cancel].
  Future<String> answer(String question, List<Map<String, String>> history) =>
      _converse(
        'You are a Flutter/Dart expert answering questions. Answer directly '
            'and concisely. Only when the question is about this project\'s '
            'code, look it up first with the tools you are given, which read '
            'it; never change files. Paths are relative to the project root.',
        [
          ...history,
          {'role': 'user', 'content': question},
        ],
        'Stopped after ${AppMetric.aiMaxAnswerRounds} steps without an '
            'answer; ask a narrower question.',
        skills: skillsFor(edits: false),
        maxRounds: AppMetric.aiMaxAnswerRounds,
      );

  /// Carries out the user's [request] on the project, with the earlier
  /// chat [history] (`role`/`content` messages) for context, and returns
  /// the model's summary of what it changed. FIDE's whole-project fixes
  /// are offered only when the request names their subject
  /// ([QuickFix.isNamedIn]).
  ///
  /// Throws an [AiServiceException] when the model can't be reached, and
  /// an [AiCancelledException] after [cancel].
  Future<String> edit(String request, List<Map<String, String>> history) {
    final fixes = [
      for (final fix in QuickFix.values)
        if (fix.isNamedIn(request)) fix,
    ];
    final skills = skillsFor(edits: true, fixes: fixes);
    final offersFixes = skills.any((skill) => skill.name == _quickFixName);
    return _converse(
      'You are a Flutter/Dart developer working on this project with the '
          'tools you are given. Make the change the user asks for in the '
          'files yourself: never reply with code for the user to apply. '
          'Use search to find code, read each file before you change it, '
          'prefer replace_in_file, keep to the code style around it, '
          'change nothing the request doesn\'t ask for, then call '
          'check_build and fix any errors you caused. Reply with a short '
          'summary naming each file you changed. Paths are relative to the '
          'project root.'
          '${offersFixes ? ' For ${fixes.map((fix) => fix.label).join(', ')}, call $_quickFixName first, then edit by hand only what it left.' : ''}',
      [
        ...history,
        {'role': 'user', 'content': request},
      ],
      'Stopped after ${AppMetric.aiMaxToolRounds} steps; the change may '
          'be incomplete.',
      skills: skills,
    );
  }

  /// Asks the model to fix the build that failed with [errors], with the
  /// user's [notes], and returns its closing summary; a thinking model
  /// reasons before each step, as tracing errors to their cause needs it.
  ///
  /// Throws an [AiServiceException] when the model can't be reached, and
  /// an [AiCancelledException] after [cancel].
  Future<String> fixBuild(String errors, String notes) => _converse(
    'You fix broken Flutter/Dart builds by editing the project with '
        'the tools you are given. Read each file before you change it, '
        'make the smallest change that fixes the root cause, then call '
        'check_build. Repeat until the build succeeds, then reply with '
        'a short summary of what you changed. Paths are relative to the '
        'project root.',
    [
      {
        'role': 'user',
        'content':
            'Build errors:\n'
            '${errors.truncated(AppMetric.aiBuildErrorChars)}\n\n$notes',
      },
    ],
    'Stopped after ${AppMetric.aiMaxToolRounds} steps without a '
        'passing build.',
    skills: skillsFor(edits: true),
    think: true,
  );

  /// Runs the tool loop: sends [system] and [conversation] to the model
  /// with [skills], runs those it calls, and returns its first reply that
  /// calls none, or [stoppedMessage] after [maxRounds] rounds; [think]
  /// lets a thinking model reason before each step.
  Future<String> _converse(
    String system,
    List<Map<String, String>> conversation,
    String stoppedMessage, {
    required List<AiSkill> skills,
    int maxRounds = AppMetric.aiMaxToolRounds,
    bool think = false,
  }) async {
    final tools = [for (final skill in skills) skill.toTool()];
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...conversation,
    ];
    for (var round = 0; round < maxRounds; round++) {
      _cancelToken.throwIfCancelled();
      _fitBudget(messages, tools);
      final reply = await _model.chat(
        messages,
        tools,
        think: think,
        cancel: _cancelToken,
        onText: hooks.onText,
      );
      messages.add(reply);
      final calls = reply['tool_calls'];
      if (calls is! List || calls.isEmpty) {
        return reply['content']?.toString() ?? '';
      }
      for (final call in calls) {
        _cancelToken.throwIfCancelled();
        final function = call is Map ? call['function'] : null;
        if (function is! Map) continue;
        final name = function['name']?.toString() ?? '';
        final arguments = function['arguments'];
        messages.add({
          'role': 'tool',
          'tool_name': name,
          'tool_call_id': ?call['id'],
          'content': await _runSkill(
            skills,
            name,
            arguments is Map<String, dynamic> ? arguments : const {},
          ),
        });
      }
    }
    return stoppedMessage;
  }

  /// Keeps [messages], sent with [tools], within the model's
  /// [ChatModel.contextBudget]: once they outgrow it, the output of the
  /// oldest calls, and the text they wrote, give way to a note, as the
  /// model can call the tool again, until they are back under
  /// [AppMetric.aiContextKeptShare] of it; the latest reply's calls stay
  /// whole. A local model slows down sharply as its context fills, and
  /// past it Ollama would cut the start of the conversation, the request
  /// with it.
  void _fitBudget(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) {
    final budget = _model.contextBudget;
    int tokens(Object? value) =>
        jsonEncode(value).length ~/ AppMetric.aiCharsPerToken;
    var size = tokens([messages, tools]);
    if (budget == null || size <= budget) return;
    final target = (budget * AppMetric.aiContextKeptShare).floor();
    final latest = messages.lastIndexWhere(
      (message) => message['role'] == 'assistant',
    );
    for (var index = 0; index < latest; index++) {
      if (size <= target) return;
      final message = messages[index];
      final smaller = switch (message) {
        {'role': 'tool', 'content': final String content}
            when content.length >= AppMetric.aiDroppableOutputChars =>
          {
            ...message,
            'content':
                'Output dropped to save memory; call '
                '${message['tool_name']} again if you need it.',
          },
        {'role': 'assistant', 'tool_calls': final List calls} => {
          ...message,
          'tool_calls': [for (final call in calls) _withoutLongArguments(call)],
        },
        _ => message,
      };
      size -= tokens(message) - tokens(smaller);
      messages[index] = smaller;
    }
  }

  /// [call] with each long argument, such as the content of a file it
  /// wrote, replaced by its size.
  static Object? _withoutLongArguments(Object? call) {
    if (call
        case final Map map &&
            {'function': final Map function && {'arguments': final Map args}}) {
      return {
        ...map,
        'function': {
          ...function,
          'arguments': {
            for (final MapEntry(:key, :value) in args.entries)
              key: '$value'.length >= AppMetric.aiDroppableOutputChars
                  ? '(${'$value'.length} characters)'
                  : value,
          },
        },
      };
    }
    return call;
  }

  /// The string argument [name] of a skill call.
  ///
  /// Throws a [FormatException] when the model left it out.
  String _argument(Map<String, dynamic> arguments, String name) {
    final value = arguments[name];
    if (value == null) throw FormatException('Missing argument "$name"');
    return value.toString();
  }

  /// Runs the one of [skills] called [name], reporting it to
  /// [CodeEditHooks.onStep]; failures, such as a tool the model wasn't
  /// given, come back as text so the model can correct itself.
  Future<String> _runSkill(
    List<AiSkill> skills,
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final subject = arguments['path'] ?? arguments['text'];
    hooks.onStep(subject == null ? name : '$name $subject');
    final skill = skills.where((s) => s.name == name).firstOrNull;
    if (skill == null) return 'Error: unknown tool $name';
    try {
      return await skill.run(arguments);
    } on FormatException catch (e) {
      return 'Error: ${e.message}';
    } on FileSystemException catch (e) {
      return 'Error: ${e.message} ${e.path ?? ''}';
    }
  }

  /// Writes [content] to the project file at [path] and runs
  /// [CodeEditHooks.onFileWritten] with its absolute path.
  Future<String> _write(String path, String content) async {
    await files.write(path, content);
    final absolute = files.resolve(path);
    await hooks.onFileWritten(absolute);
    return 'Saved ${p.relative(absolute, from: projectPath)}.';
  }
}
