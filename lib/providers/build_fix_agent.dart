import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:path/path.dart' as p;

part 'build_fix_agent.ai_skill.dart';
part 'build_fix_agent.build_fix_hooks.dart';

/// Fixes a broken build by letting the model read and edit the project's
/// files through [skills], rebuilding until the build passes or it gives up.
///
/// Every path a skill touches must lie inside [projectPath].
class BuildFixAgent {
  /// Folders [listFiles] skips: tool output and hidden folders.
  static const Set<String> _skippedFolders = {'build', '.dart_tool', '.git'};

  final AIService _ai;

  /// Root of the project the model may read and edit.
  final String projectPath;

  /// What the agent calls as it works.
  final BuildFixHooks hooks;

  /// Creates an agent that talks to the model through [_ai].
  BuildFixAgent(this._ai, {required this.projectPath, required this.hooks});

  /// The tools the model may call.
  late final List<AiSkill> skills = [
    AiSkill(
      name: 'list_files',
      description: 'Lists the files under a project folder, recursively.',
      parameters: {'path': 'Folder relative to the project root, or "."'},
      run: (args) => listFiles(_argument(args, 'path')),
    ),
    AiSkill(
      name: 'read_file',
      description: 'Returns the content of a project file.',
      parameters: {'path': 'File relative to the project root'},
      run: (args) async =>
          _truncate(await _resolve(_argument(args, 'path')).readAsString()),
    ),
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
          _write(_resolve(_argument(args, 'path')), _argument(args, 'content')),
    ),
    AiSkill(
      name: 'check_build',
      description:
          'Rebuilds the project and returns the build errors, or says the '
          'build succeeded.',
      parameters: const {},
      run: (_) async {
        final errors = await hooks.checkBuild();
        return errors.isEmpty ? 'Build succeeded.' : _truncate(errors);
      },
    ),
  ];

  /// Files under [folder] (relative to [projectPath]), one relative path
  /// per line, at most [AppMetric.aiMaxListedFiles] of them.
  Future<String> listFiles(String folder) async {
    final files = <String>[];
    await for (final entity in Directory(
      _resolve(folder).path,
    ).list(recursive: true)) {
      final relative = p.relative(entity.path, from: projectPath);
      if (entity is! File || p.split(relative).any(_isSkipped)) continue;
      files.add(relative);
      if (files.length >= AppMetric.aiMaxListedFiles) break;
    }
    return (files..sort()).join('\n');
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
    final file = _resolve(path);
    final content = await file.readAsString();
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
      file,
      content.replaceRange(index, index + oldText.length, newText),
    );
  }

  /// Asks the model to fix the build that failed with [errors], with the
  /// user's [notes], and returns its closing summary.
  ///
  /// Throws an [AiServiceException] when the model can't be reached.
  Future<String> run(String errors, String notes) async {
    final tools = [for (final skill in skills) skill.toTool()];
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You fix broken Flutter/Dart builds by editing the project with '
            'the tools you are given. Read each file before you change it, '
            'make the smallest change that fixes the root cause, then call '
            'check_build. Repeat until the build succeeds, then reply with '
            'a short summary of what you changed. Paths are relative to the '
            'project root.',
      },
      {'role': 'user', 'content': 'Build errors:\n$errors\n\n$notes'},
    ];
    for (var round = 0; round < AppMetric.aiMaxToolRounds; round++) {
      final reply = await _ai.chat(messages, tools);
      messages.add(reply);
      final calls = reply['tool_calls'];
      if (calls is! List || calls.isEmpty) {
        return reply['content']?.toString() ?? '';
      }
      for (final call in calls) {
        final function = call is Map ? call['function'] : null;
        if (function is! Map) continue;
        final name = function['name']?.toString() ?? '';
        final arguments = function['arguments'];
        messages.add({
          'role': 'tool',
          'tool_name': name,
          'content': await _runSkill(
            name,
            arguments is Map<String, dynamic> ? arguments : const {},
          ),
        });
      }
    }
    return 'Stopped after ${AppMetric.aiMaxToolRounds} steps without a '
        'passing build.';
  }

  /// The string argument [name] of a skill call.
  ///
  /// Throws a [FormatException] when the model left it out.
  String _argument(Map<String, dynamic> arguments, String name) {
    final value = arguments[name];
    if (value == null) throw FormatException('Missing argument "$name"');
    return value.toString();
  }

  /// Whether [segment] of a relative path is a folder [listFiles] skips.
  bool _isSkipped(String segment) =>
      _skippedFolders.contains(segment) || segment.startsWith('.');

  /// The file at [path], relative to [projectPath] or absolute inside it.
  ///
  /// Throws a [FormatException] for paths outside the project.
  File _resolve(String path) {
    final resolved = p.normalize(p.join(projectPath, path));
    if (resolved != p.normalize(projectPath) &&
        !p.isWithin(projectPath, resolved)) {
      throw FormatException('$path is outside the project');
    }
    return File(resolved);
  }

  /// Runs the skill called [name], reporting it to [BuildFixHooks.onStep];
  /// failures come back as text so the model can correct itself.
  Future<String> _runSkill(String name, Map<String, dynamic> arguments) async {
    final path = arguments['path'];
    hooks.onStep(path == null ? name : '$name $path');
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

  /// [text] cut to [AppMetric.aiMaxReadChars].
  String _truncate(String text) => text.length > AppMetric.aiMaxReadChars
      ? '${text.substring(0, AppMetric.aiMaxReadChars)}...'
      : text;

  /// Writes [content] to [file], creating its folders, and runs
  /// [BuildFixHooks.onFileWritten].
  Future<String> _write(File file, String content) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    await hooks.onFileWritten(file.path);
    return 'Saved ${p.relative(file.path, from: projectPath)}.';
  }
}
