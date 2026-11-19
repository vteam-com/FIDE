import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/project_command.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_command_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Answers `runUntil` with [result] after running [effect], recording each
/// command and the folder it ran in; throws [error] instead when given.
class _ScriptedRunner extends ProcessRunner {
  _ScriptedRunner({ProcessResult? result, this.effect, this.error})
    : result = result ?? ProcessResult(0, 0, '', '');

  final ProcessResult result;

  final void Function()? effect;

  final Object? error;

  /// Each command run, with its folder.
  final List<(String, String?)> ran = [];

  /// The stop of each run.
  final List<Future<void>?> stops = [];

  @override
  Future<ProcessResult> runUntil(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Future<void>? stop,
  }) async {
    ran.add(([executable, ...arguments].join(' '), workingDirectory));
    stops.add(stop);
    if (error case final error?) throw error;
    effect?.call();
    return result;
  }
}

void main() {
  late Directory project;
  late File lock;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_command_');
    lock = File(p.join(project.path, 'pubspec.lock'))
      ..writeAsStringSync('google_sign_in_ios: 6.3.6');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: a');
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// Runs [line] in the project root with [runner].
  Future<ProjectCommandOutcome> run(
    ProcessRunner runner,
    String line, {
    Future<void>? stop,
  }) => ProjectCommandService(runner).run(
    ProjectCommand.parse(line),
    projectPath: project.path,
    directory: project.path,
    stop: stop,
  );

  test('tells how the command went and the files it changed', () async {
    final runner = _ScriptedRunner(
      result: ProcessResult(
        0,
        0,
        '> google_sign_in_ios 6.4.0 (was 6.3.6)\nChanged 1 dependency!',
        '',
      ),
      effect: () => lock
        ..writeAsStringSync('google_sign_in_ios: 6.4.0')
        ..setLastModifiedSync(DateTime(2030)),
    );
    final stop = Completer<void>().future;

    final outcome = await run(
      runner,
      'flutter pub upgrade google_sign_in_ios',
      stop: stop,
    );

    expect(runner.ran.single, (
      'flutter pub upgrade google_sign_in_ios',
      project.path,
    ));
    expect(runner.stops.single, same(stop));
    expect(outcome.changedFiles, [lock.path]);
    expect(
      outcome.summary,
      'flutter pub upgrade google_sign_in_ios succeeded.\n'
      'Changed: pubspec.lock.\n'
      'Output:\n'
      '> google_sign_in_ios 6.4.0 (was 6.3.6)\nChanged 1 dependency!',
    );
  });

  test('a failure keeps the end of its output, where the error is', () async {
    final noise =
        'Resolving dependencies...\n' * AppMetric.aiCommandOutputChars;
    final runner = _ScriptedRunner(
      result: ProcessResult(0, 1, noise, 'version solving failed.'),
    );

    final outcome = await run(runner, 'flutter pub get');

    expect(
      outcome.summary,
      startsWith(
        'flutter pub get failed with exit code 1.\n'
        'No project file changed.\nOutput:\n…',
      ),
    );
    expect(outcome.summary, endsWith('version solving failed.'));
    expect(outcome.changedFiles, isEmpty);
  });

  test(
    'runs dart as resolved, so pub uses the SDK the project builds with',
    () async {
      final runner = _ScriptedRunner();

      await ProjectCommandService(runner, () async => '/sdk/bin/dart').run(
        ProjectCommand.parse('dart pub get'),
        projectPath: project.path,
        directory: project.path,
      );

      expect(runner.ran.single.$1, '/sdk/bin/dart pub get');
    },
  );

  test('a command that cannot start says so', () async {
    final runner = _ScriptedRunner(
      error: const ProcessException('pod', ['install'], 'No such file'),
    );

    final outcome = await run(runner, 'pod install');

    expect(outcome.summary, "Couldn't run pod install: No such file");
    expect(outcome.changedFiles, isEmpty);
  });
}
