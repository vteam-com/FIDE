import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/project_command.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

/// What a [ProjectCommand] did: how it went, for the model, and the
/// absolute paths of the project files it changed, for the editor.
typedef ProjectCommandOutcome = ({String summary, List<String> changedFiles});

/// Runs the [ProjectCommand]s the AI agent asks for in a project, telling
/// how each went and which files it changed, so the agent needn't run
/// another command or read the files to find out.
class ProjectCommandService {
  /// Creates a service launching commands through [_runner], `dart` as
  /// [_dart] resolves it, such as `bundledDartProvider`, so `dart pub`
  /// uses the SDK the project builds with.
  const ProjectCommandService(
    this._runner, [
    this._dart = FlutterSdk.dartOnPath,
  ]);

  final ProcessRunner _runner;

  final DartCommand _dart;

  /// Runs [command] in [directory], a folder of the project at
  /// [projectPath], until it exits or [stop] completes, which kills it.
  ///
  /// Its summary says whether it succeeded, names the files it changed and
  /// ends with the last [AppMetric.aiCommandOutputChars] of its output; a
  /// command that can't start, such as `pod` where CocoaPods isn't
  /// installed, says so.
  Future<ProjectCommandOutcome> run(
    ProjectCommand command, {
    required String projectPath,
    required String directory,
    Future<void>? stop,
  }) async {
    final before = await _modifiedTimes(projectPath);
    final ProcessResult result;
    try {
      result = await _runner.runUntil(
        command.executable == FlutterSdk.dartExecutable
            ? await _dart()
            : command.executable,
        command.arguments,
        workingDirectory: directory,
        stop: stop,
      );
    } on ProcessException catch (e) {
      return (
        summary: "Couldn't run ${command.line}: ${e.message}",
        changedFiles: const <String>[],
      );
    }
    final after = await _modifiedTimes(projectPath);
    final changed = [
      for (final MapEntry(key: path, value: modified) in after.entries)
        if (before[path] != modified) path,
    ];
    return (
      summary: _summary(command, result, projectPath, changed),
      changedFiles: changed,
    );
  }

  /// How [command] went, from its [result], naming the [changed] files
  /// relative to [projectPath]: the model's whole view of the run.
  static String _summary(
    ProjectCommand command,
    ProcessResult result,
    String projectPath,
    List<String> changed,
  ) {
    final output = [
      '${result.stdout}'.trim(),
      '${result.stderr}'.trim(),
    ].where((text) => text.isNotEmpty).join('\n');
    final listed = [
      for (final path in changed.take(AppMetric.aiMaxChangedFilesListed))
        p.relative(path, from: projectPath),
      if (changed.length > AppMetric.aiMaxChangedFilesListed)
        'and ${changed.length - AppMetric.aiMaxChangedFilesListed} more',
    ];
    return [
      result.exitCode == 0
          ? '${command.line} succeeded.'
          : '${command.line} failed with exit code ${result.exitCode}.',
      listed.isEmpty
          ? 'No project file changed.'
          : 'Changed: ${listed.join(', ')}.',
      if (output.isNotEmpty)
        'Output:\n${output.truncatedStart(AppMetric.aiCommandOutputChars)}',
    ].join('\n');
  }

  /// When each file of the project at [projectPath] was last modified,
  /// by absolute path, leaving out tool output and installed dependencies
  /// ([ProjectFiles.skippedFolders]).
  static Future<Map<String, DateTime>> _modifiedTimes(
    String projectPath,
  ) async {
    final times = <String, DateTime>{};
    try {
      await for (final file in ProjectFiles.walk(projectPath)) {
        try {
          times[file.path] = file.statSync().modified;
        } on FileSystemException {
          // Removed while listed: not there to compare
        }
      }
    } on FileSystemException {
      // The project can't be listed: no file to report
    }
    return times;
  }
}
