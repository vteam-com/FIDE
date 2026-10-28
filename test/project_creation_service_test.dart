import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/project_creation_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Scaffolds a minimal project for `flutter create`, fails the commands in
// [failing], and succeeds everything else
class FakeToolsRunner extends ProcessRunner {
  final Set<String> failing;
  final List<String> commands = [];

  FakeToolsRunner({this.failing = const {}});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    if (failing.contains(command)) return ProcessResult(0, 1, '', 'failed');
    if (executable == 'flutter' && arguments.first == 'create') {
      final project = arguments.last;
      File('$project/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'name: demo\nflutter:\n  uses-material-design: true\n',
        );
      File('$project/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      Directory('$project/android').createSync();
      Directory('$project/ios').createSync();
    }
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory parent;
  late List<(int, LoadingStatus)> progress;

  setUp(() {
    parent = Directory.systemTemp.createTempSync('fide_create_');
    progress = [];
  });

  tearDown(() => parent.deleteSync(recursive: true));

  ProjectCreationService serviceFor(FakeToolsRunner runner) =>
      ProjectCreationService(
        runner,
        GitService(runner),
        LocalizationService(runner),
        const AIService(),
      );

  void record(int step, String _, LoadingStatus status) =>
      progress.add((step, status));

  ProjectCreationRequest request({
    bool flutterAvailable = true,
    Set<String>? languages,
    bool initGit = false,
  }) => ProjectCreationRequest(
    name: 'demo',
    parentDirectory: parent.path,
    flutterAvailable: flutterAvailable,
    languages: languages,
    initGit: initGit,
  );

  test('creates the project and reports every step as done', () async {
    final runner = FakeToolsRunner();

    final created = await serviceFor(runner)
        .create(request(languages: {'en', 'fr'}, initGit: true), record);

    expect(created, true);
    expect(
      progress.map((entry) => entry.$2),
      everyElement(LoadingStatus.success),
    );
    expect(progress.last.$1, AppMetric.projectCreateStepVerification);
    expect(File('${parent.path}/demo/lib/l10n/app_fr.arb').existsSync(), true);
    expect(runner.commands, contains('git commit -m Initial commit'));
  });

  test('fails at validation when Flutter is missing', () async {
    final runner = FakeToolsRunner();

    final created = await serviceFor(runner)
        .create(request(flutterAvailable: false), record);

    expect(created, false);
    expect(progress.single, (
      AppMetric.projectCreateStepValidate,
      LoadingStatus.failed,
    ));
    expect(runner.commands, isEmpty);
  });

  test(
    'a failed commit is reported but the project is still created',
    () async {
      final runner = FakeToolsRunner(failing: {'git commit -m Initial commit'});

      final created = await serviceFor(runner)
          .create(request(initGit: true), record);

      expect(created, true);
      expect(
        progress,
        contains((AppMetric.projectCreateStepGitInit, LoadingStatus.failed)),
      );
    },
  );
}
