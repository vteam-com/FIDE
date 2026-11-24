import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/model_message.dart';
import 'package:fide/models/prompt_intent.dart';
import 'package:fide/models/project_command.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/text_offsets.dart';
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

  /// Name of the tool running Flutter, Dart and CocoaPods commands.
  static const String _commandName = 'run_command';

  /// Name of the tool renaming and moving files, imports following them.
  static const String _renameName = 'rename_file';

  /// Where a build or analyzer error points: a Dart file and a line.
  static final RegExp _errorLocation = RegExp(
    r'(?<path>[^\s:]+\.dart):(?<line>\d+)',
  );

  /// Whether a skill that changes the project succeeded since [edit]
  /// started.
  bool _wroteFiles = false;

  /// Appended to an edit's reply when no file changed, whatever it claims.
  static const String noFileChangedNote = 'No file was changed.';

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

  /// The tools the model may call: reading the project always; editing
  /// it when [edits], running the commands FIDE allows and FIDE's own
  /// whole-project [fixes], only those the request names, when the caller
  /// runs them.
  List<AiSkill> skillsFor({
    required bool edits,
    List<QuickFix> fixes = const [],
  }) => [
    ..._readSkills,
    if (edits) ..._editSkills,
    if (edits) ?_renameSkill(),
    if (edits) ?_commandSkill(),
    if (edits) ?_quickFixSkill(fixes),
  ];

  /// The tools reading the project.
  late final List<AiSkill> _readSkills = [
    AiSkill(
      name: 'list_files',
      icon: '📂',
      description: 'Lists the files under a project folder, recursively.',
      parameters: {'path': 'Folder relative to the project root, or "."'},
      run: (args) => listFiles(_argument(args, 'path')),
    ),
    AiSkill(
      name: 'search',
      icon: '🔍',
      description:
          'Finds the lines of the project files holding a text, whatever '
          'its case, as path:line: text. Plain text, not a pattern. Faster '
          'than reading files to find where something is.',
      parameters: {'text': 'Text to find, such as a class or method name'},
      run: (args) => search(_argument(args, 'text')),
    ),
    AiSkill(
      name: 'read_file',
      icon: '👓',
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
      icon: '✏️',
      description:
          'Replaces text that occurs exactly once in a project file, or '
          'every occurrence with replace_all. Prefer it to write_file for '
          'small fixes. Answers with the lines it changed.',
      parameters: {
        'path': 'File relative to the project root',
        'old_text': 'Exact text to replace, including whitespace',
        'new_text': 'Replacement text',
      },
      optionalParameters: {
        'replace_all': '"true" to replace every occurrence, as for a rename',
      },
      changesProject: true,
      run: (args) => replaceInFile(
        _argument(args, 'path'),
        _argument(args, 'old_text'),
        _argument(args, 'new_text'),
        all: '${args['replace_all']}'.toLowerCase() == 'true',
      ),
    ),
    AiSkill(
      name: 'write_file',
      icon: '✏️',
      description: 'Creates or overwrites a project file with new content.',
      parameters: {
        'path': 'File relative to the project root',
        'content': 'The complete new file content',
      },
      changesProject: true,
      run: (args) async {
        final path = _argument(args, 'path');
        final content = _argument(args, 'content');
        if (await _copied(path, content) case final original?) {
          throw FormatException(
            '$path would be a copy of $original: call $_renameName to '
            'rename or move it.',
          );
        }
        return _write(path, content);
      },
    ),
    AiSkill(
      name: 'check_build',
      icon: '🔨',
      description:
          'Checks the project for compile errors and returns them, or says '
          'the build succeeded.',
      // A parameter, as qwen3-coder can leave a call with none unclosed,
      // which Ollama then fails to read
      parameters: {'changes': 'What you changed, in a few words'},
      usesArguments: false,
      run: (_) async {
        final errors = await hooks.checkBuild();
        return errors.isEmpty
            ? 'Build succeeded.'
            : (await _withSourceLines(errors))
                  .truncated(AppMetric.aiBuildErrorChars);
      },
    ),
  ];

  /// The tool renaming or moving a project file or folder, the imports
  /// naming it following it; null when the caller renames none.
  AiSkill? _renameSkill() {
    final renameFile = hooks.renameFile;
    if (renameFile == null) return null;
    return AiSkill(
      name: _renameName,
      icon: '🏷️',
      description:
          'Renames or moves a project file or folder, and points every '
          'import, export and part naming a Dart file it moves at its new '
          'path, in lib and test alike. Use it to rename a file: never '
          'write a copy, and never edit those imports yourself.',
      parameters: {
        'path': 'File or folder relative to the project root',
        'new_path': 'Its new path, relative to the project root',
      },
      changesProject: true,
      run: (args) async {
        final from = files.resolve(_argument(args, 'path'));
        final to = files.resolve(_argument(args, 'new_path'));
        final written = await renameFile(from, to);
        final others = written
            .where((path) => path != to && !p.isWithin(to, path))
            .length;
        return 'Renamed ${p.relative(from, from: projectPath)} to '
            '${p.relative(to, from: projectPath)}'
            '${others == 0 ? '; no other file imports it.' : ', and pointed the imports of $others other files at it.'}';
      },
    );
  }

  /// The tool running one of the [ProjectCommand]s FIDE allows, such as
  /// `flutter pub upgrade`, in a project folder; null when the caller runs
  /// none.
  AiSkill? _commandSkill() {
    final runCommand = hooks.runCommand;
    if (runCommand == null) return null;
    return AiSkill(
      name: _commandName,
      icon: '💻',
      description:
          'Runs one command in the project and returns how it went, the '
          'files it changed and its output. flutter pub upgrade <package> '
          'updates a package, even an indirect one, within the pubspec.yaml '
          'constraints; pod install runs in folder ios. Run the commands a '
          'change needs yourself: never ask the user to. Allowed: '
          '${ProjectCommand.allowed}.',
      parameters: {'command': 'The command line, such as flutter pub get'},
      optionalParameters: {
        'folder':
            'Project folder to run it in, such as ios; the root '
            'by default',
      },
      changesProject: true,
      run: (args) => runCommand(
        ProjectCommand.parse(_argument(args, 'command')),
        files.resolve('${args['folder'] ?? '.'}'),
      ),
    );
  }

  /// The tool running one of FIDE's whole-project [fixes]; null when there
  /// are none or the caller runs none.
  AiSkill? _quickFixSkill(List<QuickFix> fixes) {
    final runQuickFix = hooks.runQuickFix;
    if (runQuickFix == null || fixes.isEmpty) return null;
    return AiSkill(
      name: _quickFixName,
      icon: '🪄',
      description:
          'Has FIDE do a whole-project fix itself, faster and safer than '
          'editing files: ${[for (final fix in fixes) '${fix.name} ${fix.purpose}'].join('; ')}. '
          'Returns what it changed and what it left for you.',
      parameters: {'name': 'One of ${fixes.map((fix) => fix.name).join(', ')}'},
      changesProject: true,
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
    for (final path in listed) {
      _addSearchTerms(path);
    }
    return listed.join('\n');
  }

  /// The lines of the project's files holding [text], one `path:line:
  /// text` per line, at most [AppMetric.aiSearchMaxResults] of them.
  Future<String> search(String text) async {
    final terms = _searchTerms;
    final lowered = text.toLowerCase();
    if (terms != null && !terms.any((term) => term.contains(lowered))) {
      return 'Not searched: "$text" is not in your question or in the file '
          'names listed. Search only for words from those, such as a file '
          'name you listed.';
    }
    final found = await files.search(text, limit: AppMetric.aiSearchMaxResults);
    return found.isEmpty
        ? 'No match for "$text". Search takes plain text, not a pattern: '
              'try a shorter part of it.'
        : found.join('\n');
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

  /// Replaces the single occurrence of [oldText] in [path] with
  /// [newText], or every one when [all], and answers with the lines it
  /// changed.
  ///
  /// Throws a [FormatException] when [oldText] is missing or, unless
  /// [all], not unique, showing where it, or its first line, is, so the
  /// model can retry without reading the file.
  Future<String> replaceInFile(
    String path,
    String oldText,
    String newText, {
    bool all = false,
  }) async {
    final content = await files.read(path);
    final starts = oldText.isEmpty
        ? const <int>[]
        : [for (final match in oldText.allMatches(content)) match.start];
    if (starts.isEmpty) {
      throw FormatException(
        'old_text not found in $path. ${_nearMatches(content, oldText)}'
            .truncated(AppMetric.aiEditHintChars),
      );
    }
    if (starts.length > 1 && !all) {
      throw FormatException(
        'old_text occurs ${starts.length} times in $path: include more of '
                'the lines around the one to change, or set replace_all to '
                'true to change them all.\n'
                '${[for (final start in starts) _excerpt(content, start, start + oldText.length)].join('\n')}'
            .truncated(AppMetric.aiEditHintChars),
      );
    }
    if (all) {
      final saved = await _write(path, content.replaceAll(oldText, newText));
      return '$saved Replaced ${starts.length} occurrences.';
    }
    final start = starts.single;
    final replaced = content.replaceRange(
      start,
      start + oldText.length,
      newText,
    );
    final saved = await _write(path, replaced);
    return '$saved Now ${_excerpt(replaced, start, start + newText.length)}'
        .truncated(AppMetric.aiReadFileChars);
  }

  /// Where the first line of [oldText], which [content] doesn't hold as
  /// is, appears once indentation is set aside: most often the model
  /// mistyped the whitespace. Empty when it appears nowhere either.
  static String _nearMatches(String content, String oldText) {
    final first = const LineSplitter()
        .convert(oldText)
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (first.isEmpty) return '';
    final near = [
      for (final match in first.allMatches(content))
        _excerpt(content, match.start, match.end),
    ];
    return near.isEmpty
        ? 'Read the file to copy the text exactly.'
        : 'Its first line is in these lines; copy old_text from them '
              'exactly, whitespace included:\n${near.join('\n')}';
  }

  /// The lines of [content] from the one holding [start] to the one
  /// holding [end], with [AppMetric.aiEditContextLines] more on each side,
  /// exactly as the file has them, under a heading numbering them from 1:
  /// what an edit made, or where a text is, so the model needn't read the
  /// file to see it.
  static String _excerpt(String content, int start, int end) {
    final lines = const LineSplitter().convert(content);
    int lineOf(int offset) => TextOffsets.positionOf(content, offset).line - 1;
    final first = (lineOf(start) - AppMetric.aiEditContextLines).clamp(
      0,
      lines.length,
    );
    final last = (lineOf(end) + AppMetric.aiEditContextLines + 1).clamp(
      first,
      lines.length,
    );
    return 'lines ${first + 1} to $last:\n'
        '${lines.sublist(first, last).join('\n')}';
  }

  /// [errors] with each line naming a project file and line, as
  /// `lib/a.dart:12: …` or `lib/a.dart:12:5: Error: …`, followed by that
  /// line of code, so the model needn't read the file to find it.
  Future<String> _withSourceLines(String errors) async {
    final contents = <String, List<String>?>{};
    final annotated = <String>[];
    for (final error in const LineSplitter().convert(errors)) {
      annotated.add(error);
      final match = _errorLocation.firstMatch(error);
      if (match == null) continue;
      final path = match.namedGroup('path')!;
      final lines = contents[path] ??= await _linesOf(path);
      final number = int.parse(match.namedGroup('line')!);
      if (lines != null && number >= 1 && number <= lines.length) {
        annotated.add('    $number | ${lines[number - 1].trim()}');
      }
    }
    return annotated.join('\n');
  }

  /// The project file that [content], written to the new file [path],
  /// would copy, when files can be renamed; null when there is none.
  /// Asked to rename a file, MiMo wrote a copy of it and edited the
  /// imports by hand, though the rename tool said never to.
  Future<String?> _copied(String path, String content) async {
    final copy = const LineSplitter().convert(content).join('\n').trim();
    if (hooks.renameFile == null ||
        copy.isEmpty ||
        await _linesOf(path) != null) {
      return null;
    }
    // Its longest line, which few other files hold
    final probe = const LineSplitter()
        .convert(copy)
        .map((line) => line.trim())
        .reduce(
          (longest, line) => line.length > longest.length ? line : longest,
        );
    final found = await files.search(
      probe,
      limit: AppMetric.aiSearchMaxResults,
    );
    for (final candidate in {
      for (final line in found) line.substring(0, line.indexOf(':')),
    }) {
      if ((await _linesOf(candidate))?.join('\n').trim() == copy) {
        return candidate;
      }
    }
    return null;
  }

  /// The lines of the project file at [path], or null when it can't be
  /// read.
  Future<List<String>?> _linesOf(String path) async {
    try {
      return const LineSplitter().convert(await files.read(path));
    } on Exception {
      return null;
    }
  }

  /// Answers the user's [question], with the earlier chat [history]
  /// (`role`/`content` messages) for context, reading the project's code
  /// when the question is about it, and never changing it: the model gets
  /// no tool that writes, builds or runs a fix.
  ///
  /// Throws an [AiServiceException] when the model can't be reached, and
  /// an [AiCancelledException] after [cancel].
  Future<String> answer(
    String question,
    List<Map<String, String>> history,
  ) async {
    _filesRead.clear();
    _searchTerms = [];
    _addSearchTerms(question);
    try {
      return await _answer(question, history);
    } finally {
      _searchTerms = null;
    }
  }

  /// [answer]'s reply, once its search words are set up.
  Future<String> _answer(
    String question,
    List<Map<String, String>> history,
  ) async {
    final reply = await _converse(
      'You are a Flutter/Dart expert answering questions. Answer directly '
          'and concisely. Only when the question is about this project\'s '
          'code, look it up first with the tools you are given, which read '
          'it; never change files. For a question about the whole project, '
          'list its folders first, then search for words taken from the '
          'question or from the names you listed, never words you guess. '
          'Finish with the answer itself, never a plan or what you will do '
          'next. State only what you checked in the files, and never think '
          'aloud or correct yourself in the answer. Earlier messages may be '
          'out of date: before saying what the project contains, look it up '
          'with the tools, and never report changes made in earlier turns as '
          'if they were made now. Paths are relative to the project root.',
      [...history, ModelMessage.user(question)],
      'Stopped after ${AppMetric.aiMaxAnswerRounds} steps without an '
          'answer; ask a narrower question.',
      skills: skillsFor(edits: false),
      maxRounds: AppMetric.aiMaxAnswerRounds,
      maxTokens: AppMetric.aiAnswerMaxTokens,
      // A local model can keep reading, or read one file again and
      // again, after it found the answer
      // Only a question asking for every match can miss some
      withNote: PromptIntent.asksForAll(question),
      lastAsk:
          'You are out of steps: answer the question now from the files '
          'you have read. Call no more tools, and claim nothing about '
          'files you did not read.',
    );
    if (_isLooping(reply)) {
      return 'No answer: the AI repeated itself. Ask again, or narrow the '
          'question.';
    }
    if (_isUnfinished(reply) || _thinksAloud(reply)) {
      return 'No answer: the AI stopped before finding one. Ask again, or '
          'narrow the question.';
    }
    final read = _filesRead.length;
    if (read == 0) return reply;
    return '$reply\n\n(Read $read ${read == 1 ? 'file' : 'files'} to answer.)';
  }

  /// Whether [reply] is a plan of what the AI will do rather than an answer:
  /// short, and either ending in a colon or saying what it will do next,
  /// as "Let me" or "I need to" do. A plan shown as the answer leaves the
  /// user with no result.
  static bool _isUnfinished(String reply) {
    final text = reply.trim();
    if (text.length > AppMetric.aiPlanMaxChars) return false;
    return text.endsWith(':') ||
        RegExp(
          r"\b(let me|i need to|i'll|i will|i have to)\b",
          caseSensitive: false,
        ).hasMatch(text);
  }

  /// Whether [reply] repeats one of its lines [AppMetric.aiRepeatedLineLimit]
  /// times or more, as a local model's loop does until its reply is cut.
  static bool _isLooping(String reply) {
    final counts = <String, int>{};
    for (final line in const LineSplitter().convert(reply)) {
      final text = line.trim();
      if (text.isEmpty) continue;
      final count = (counts[text] ?? 0) + 1;
      if (count >= AppMetric.aiRepeatedLineLimit) return true;
      counts[text] = count;
    }
    return false;
  }

  /// Whether [reply] reasons out loud, correcting itself as it goes ("wait,
  /// let me be precise"), so it states guesses as answers; such a reply
  /// isn't taken as the answer.
  static bool _thinksAloud(String reply) => RegExp(
    r"\b(wait,|let me be|let me double|let me re-?check|let me correct)",
    caseSensitive: false,
  ).hasMatch(reply);

  /// Words a question's answer may search for, lowercase: those of the
  /// question and of the names listed; null when a search is unrestricted,
  /// as an edit's is. A local model otherwise searches for misspellings it
  /// guesses from memory, which find nothing in the project.
  List<String>? _searchTerms;

  /// Adds the words of [text] to [_searchTerms], when restricted.
  void _addSearchTerms(String text) {
    final terms = _searchTerms;
    if (terms == null) return;
    terms.add(text.toLowerCase());
    terms.addAll(
      text
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((word) => word.length >= AppMetric.aiSearchTermMinChars),
    );
  }

  /// Files the question's answer read, by path, since [answer] started.
  final Set<String> _filesRead = {};

  /// Ends an answer the model gave once stopped, as it covers only what
  /// it read: asked for a typo, MiMo wrote "I checked every file in the
  /// project" after reading 7 of 267.
  static const String _partialAnswerNote =
      '(Note: the AI ran out of steps before reading every file, so this '
      'may miss other problems.)';

  /// Carries out the user's [request] on the project, with the earlier
  /// chat [history] (`role`/`content` messages) for context, and returns
  /// the model's summary of what it changed. FIDE's whole-project fixes
  /// are offered only when the request names their subject
  /// ([QuickFix.isNamedIn]).
  ///
  /// Throws an [AiServiceException] when the model can't be reached, and
  /// an [AiCancelledException] after [cancel].
  Future<String> edit(String request, List<Map<String, String>> history) async {
    _wroteFiles = false;
    final fixes = [
      for (final fix in QuickFix.values)
        if (fix.isNamedIn(request)) fix,
    ];
    final skills = skillsFor(edits: true, fixes: fixes);
    final offersFixes = skills.any((skill) => skill.name == _quickFixName);
    final renames = skills.any((skill) => skill.name == _renameName);
    final reply = await _converse(
      'You are a Flutter/Dart developer working on this project with the '
          'tools you are given. Make the change the user asks for in the '
          'files yourself: never reply with code for the user to apply. '
          'Use search to find code, read each file before you change it, '
          'prefer replace_in_file, keep to the code style around it, '
          'change nothing the request doesn\'t ask for, then call '
          'check_build and fix any errors you caused. Reply with a short '
          'summary naming each file you changed. Paths are relative to the '
          'project root.'
          '${renames ? ' Rename or move a file with $_renameName, which updates the imports naming it.' : ''}'
          '${offersFixes ? ' For ${fixes.map((fix) => fix.label).join(', ')}, call $_quickFixName first, then edit by hand only what it left.' : ''}',
      [...history, ModelMessage.user(request)],
      'Stopped after ${AppMetric.aiMaxToolRounds} steps; the change may '
          'be incomplete.',
      skills: skills,
      maxTokens: AppMetric.aiEditMaxTokens,
    );
    // The model's summary can claim changes it never made: say so
    return _wroteFiles ? reply : '$reply\n\n$noFileChangedNote';
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
      ModelMessage.user(
        'Build errors:\n'
        '${errors.truncated(AppMetric.aiBuildErrorChars)}\n\n$notes',
      ),
    ],
    'Stopped after ${AppMetric.aiMaxToolRounds} steps without a '
        'passing build.',
    skills: skillsFor(edits: true),
    think: true,
    maxTokens: AppMetric.aiEditMaxTokens,
  );

  /// Runs the tool loop: sends [system] and [conversation] to the model
  /// with [skills], runs those it calls, and returns its first reply that
  /// calls none, or [stoppedMessage] after [maxRounds] rounds or a call
  /// repeated [AppMetric.aiMaxRepeatedCalls] times; [think] lets a
  /// thinking model reason before each step, and [maxTokens], when given,
  /// ends each reply at that many tokens. Stopped so, the model is asked
  /// [lastAsk], when given, offered no tool: its reply, unless it says
  /// nothing, comes back instead of the stop, ending with
  /// [_partialAnswerNote].
  Future<String> _converse(
    String system,
    List<Map<String, String>> conversation,
    String stoppedMessage, {
    required List<AiSkill> skills,
    int maxRounds = AppMetric.aiMaxToolRounds,
    bool think = false,
    int? maxTokens,
    String? lastAsk,
    bool withNote = false,
  }) async {
    final tools = [for (final skill in skills) skill.toTool()];
    final messages = <Map<String, dynamic>>[
      ModelMessage.of(ModelMessage.systemRole, system),
      ...conversation,
    ];
    // Results of the calls since the project last changed, by call, so a
    // local model repeating one, as it can in a loop, gets told instead
    final unchanged = <String, String>{};
    var repeats = 0;
    var stopped = stoppedMessage;
    rounds:
    for (var round = 0; round < maxRounds; round++) {
      _cancelToken.throwIfCancelled();
      // Whether this round read or changed anything new; a round of only
      // repeated calls doesn't count against maxRounds, as those are
      // capped by AppMetric.aiMaxRepeatedCalls
      var fresh = false;
      // Dropped outputs may be read again, once more, without repeating
      if (_fitBudget(messages, tools)) unchanged.clear();
      final reply = await _model.chat(
        messages,
        tools,
        think: think,
        cancel: _cancelToken,
        onText: hooks.onText,
        maxTokens: maxTokens,
      );
      messages.add(reply);
      final calls = reply[ModelMessage.toolCallsKey];
      if (calls is! List || calls.isEmpty) {
        return reply[ModelMessage.contentKey]?.toString() ?? '';
      }
      for (final call in calls) {
        _cancelToken.throwIfCancelled();
        final function = call is Map ? call[ModelMessage.functionKey] : null;
        // A malformed call counts as a round, so the loop still ends
        fresh = true;
        if (function is! Map) continue;
        final name = function[ModelMessage.nameKey]?.toString() ?? '';
        final given = function[ModelMessage.argumentsKey];
        final arguments = given is Map<String, dynamic>
            ? given
            : const <String, dynamic>{};
        final skill = skills.where((s) => s.name == name).firstOrNull;
        final key = skill?.callKey(arguments);
        final earlier = unchanged[key];
        final String result;
        if (earlier != null) {
          _reportStep(skills, name, arguments);
          if (++repeats >= AppMetric.aiMaxRepeatedCalls) {
            messages.add(_toolResult(call, name, earlier));
            stopped =
                'Stopped: the model kept calling $name with nothing '
                'changed in between; the change may be incomplete.';
            break rounds;
          }
          result =
              '$earlier\n\n(Same result as your earlier $name call: '
              'nothing changed since. Act on it instead of calling it '
              'again, or reply with your summary.)';
        } else {
          fresh = true;
          if (name == 'read_file') _filesRead.add(arguments['path'].toString());
          result = await _runSkill(skills, name, arguments);
          if (skill != null && key != null) {
            if (skill.changesProject) {
              if (!result.startsWith('Error:')) _wroteFiles = true;
              unchanged.clear();
            } else {
              unchanged[key] = result;
            }
          }
        }
        messages.add(_toolResult(call, name, result));
      }
      if (!fresh) round--;
    }
    if (lastAsk == null) return stopped;
    final reply = await _replyWithoutTools(
      messages,
      lastAsk,
      think: think,
      maxTokens: maxTokens,
    );
    if (reply == null) return stopped;
    return withNote ? '$reply\n\n$_partialAnswerNote' : reply;
  }

  /// The message answering [call] of the tool [name] with [result].
  static Map<String, dynamic> _toolResult(
    Object? call,
    String name,
    String result,
  ) => {
    ...ModelMessage.of(ModelMessage.toolRole, result),
    ModelMessage.toolNameKey: name,
    ModelMessage.toolCallIdKey: ?(call is Map
        ? call[ModelMessage.idKey]
        : null),
  };

  /// The text of the model's reply to [messages] then [ask], offered no
  /// tool, as an answer from what it read: a call it still writes is left
  /// out, as none is run, and a reply that is only a call is asked for
  /// again, saying so; null when no text is left. [think] lets a thinking
  /// model reason first, and [maxTokens], when given, ends the reply at
  /// that many tokens.
  Future<String?> _replyWithoutTools(
    List<Map<String, dynamic>> messages,
    String ask, {
    required bool think,
    int? maxTokens,
  }) async {
    Future<Map<String, dynamic>> reply(String ask) {
      _cancelToken.throwIfCancelled();
      final asked = [...messages, ModelMessage.user(ask)];
      _fitBudget(asked, const []);
      return _model.chat(
        asked,
        const [],
        think: think,
        cancel: _cancelToken,
        onText: hooks.onText,
        maxTokens: maxTokens,
      );
    }

    final first = await reply(ask);
    var text = _textOf(first);
    final calls = first[ModelMessage.toolCallsKey];
    // Offered no tool, MiMo wrote a bare call in 2 runs of 6; the same
    // request writes the same call
    if (text.isEmpty && calls is List && calls.isNotEmpty) {
      text = _textOf(
        await reply(
          '$ask Your last reply was a tool call, which can\'t run any '
          'more: write your answer as text.',
        ),
      );
    }
    return text.isEmpty ? null : text;
  }

  /// The trimmed text of the model's [reply], empty when it wrote none.
  static String _textOf(Map<String, dynamic> reply) =>
      reply[ModelMessage.contentKey]?.toString().trim() ?? '';

  /// Keeps [messages], sent with [tools], within the model's
  /// [ChatModel.contextBudget]: once they outgrow it, the output of the
  /// oldest calls, and the text they wrote, give way to a note, as the
  /// model can call the tool again, until they are back under
  /// [AppMetric.aiContextKeptShare] of it; the latest reply's calls stay
  /// whole. A local model slows down sharply as its context fills, and
  /// past it Ollama would cut the start of the conversation, the request
  /// with it.
  ///
  /// Returns whether it dropped anything.
  bool _fitBudget(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) {
    final budget = _model.contextBudget;
    int tokens(Object? value) =>
        jsonEncode(value).length ~/ AppMetric.aiCharsPerToken;
    var size = tokens([messages, tools]);
    if (budget == null || size <= budget) return false;
    final target = (budget * AppMetric.aiContextKeptShare).floor();
    final latest = messages.lastIndexWhere(
      (message) => message[ModelMessage.roleKey] == ModelMessage.assistantRole,
    );
    var dropped = false;
    for (var index = 0; index < latest; index++) {
      if (size <= target) return dropped;
      final message = messages[index];
      final smaller = switch (message) {
        {
          ModelMessage.roleKey: ModelMessage.toolRole,
          ModelMessage.contentKey: final String content,
        }
            when content.length >= AppMetric.aiDroppableOutputChars =>
          {
            ...message,
            ModelMessage.contentKey:
                'Output dropped to save memory; call '
                '${message[ModelMessage.toolNameKey]} again if you need it.',
          },
        {
          ModelMessage.roleKey: ModelMessage.assistantRole,
          ModelMessage.toolCallsKey: final List calls,
        } =>
          {
            ...message,
            ModelMessage.toolCallsKey: [
              for (final call in calls) _withoutLongArguments(call),
            ],
          },
        _ => message,
      };
      size -= tokens(message) - tokens(smaller);
      dropped |= !identical(smaller, message);
      messages[index] = smaller;
    }
    return dropped;
  }

  /// [call] with each long argument, such as the content of a file it
  /// wrote, replaced by its size.
  static Object? _withoutLongArguments(Object? call) {
    if (call
        case final Map map &&
            {
              ModelMessage.functionKey:
                  final Map function &&
                  {ModelMessage.argumentsKey: final Map args},
            }) {
      return {
        ...map,
        ModelMessage.functionKey: {
          ...function,
          ModelMessage.argumentsKey: {
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
    _reportStep(skills, name, arguments);
    final skill = skills.where((s) => s.name == name).firstOrNull;
    if (skill == null) return 'Error: unknown tool $name';
    try {
      return await skill.run(arguments);
    } on FormatException catch (e) {
      return 'Error: ${e.message}';
    } on FileSystemException catch (e) {
      return 'Error: ${e.message} ${e.path ?? ''}';
    } on StateError catch (e) {
      return 'Error: ${e.message}';
    }
  }

  /// Reports the call of the skill [name] with [arguments] to
  /// [CodeEditHooks.onStep], as one line starting with the skill's icon
  /// and naming what it works on.
  void _reportStep(
    List<AiSkill> skills,
    String name,
    Map<String, dynamic> arguments,
  ) {
    final icon =
        skills.where((skill) => skill.name == name).firstOrNull?.icon ??
        AiSkill.unknownIcon;
    final subject =
        arguments['path'] ??
        arguments['text'] ??
        arguments['changes'] ??
        arguments['command'];
    final to = arguments['new_path'];
    hooks.onStep(
      subject == null
          ? '$icon $name'
          : '$icon $name $subject${to == null ? '' : ' → $to'}',
    );
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
