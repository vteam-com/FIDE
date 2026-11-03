import 'dart:io';

import 'package:fide/models/creation_outcome.dart';
import 'package:fide/models/creation_report.dart';
import 'package:fide/models/creation_step.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_creation_service.dart';
import 'package:fide/services/project_template.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

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
  late List<(CreationStep, LoadingStatus)> progress;

  setUp(() {
    parent = Directory.systemTemp.createTempSync('fide_create_');
    progress = [];
  });

  tearDown(() => parent.deleteSync(recursive: true));

  ProjectCreationService serviceFor(
    FakeToolsRunner runner, [
    FakeChatModel? model,
  ]) => ProjectCreationService(
    runner,
    GitService(runner),
    LocalizationSetup(
      runner,
      const ProjectConfigReader(),
      L10nGenerator(runner),
    ),
    L10nGenerator(runner),
    ProjectTemplate(model ?? FakeChatModel(), FlutterSdk(runner)),
  );

  void record(CreationReport report) =>
      progress.add((report.step, report.status));

  ProjectCreationRequest request({
    bool flutterAvailable = true,
    Set<String>? languages,
    String defaultLanguage = ProjectCreationRequest.englishLanguage,
    String description = '',
    bool useAi = false,
    bool initGit = false,
  }) => ProjectCreationRequest(
    name: 'demo',
    parentDirectory: parent.path,
    flutterAvailable: flutterAvailable,
    languages: languages,
    defaultLanguage: defaultLanguage,
    description: description,
    useAi: useAi,
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
    expect(progress.last.$1, CreationStep.verification);
    expect(File('${parent.path}/demo/lib/l10n/app_fr.arb').existsSync(), true);
    expect(runner.commands, contains('git commit -m Initial commit'));
  });

  test('fails at validation when Flutter is missing', () async {
    final runner = FakeToolsRunner();

    final created = await serviceFor(runner)
        .create(request(flutterAvailable: false), record);

    expect(created, false);
    expect(progress.single, (CreationStep.validate, LoadingStatus.failed));
    expect(runner.commands, isEmpty);
  });

  test(
    'a failed commit is reported but the project is still created',
    () async {
      final runner = FakeToolsRunner(failing: {'git commit -m Initial commit'});

      final created = await serviceFor(runner)
          .create(request(initGit: true), record);

      expect(created, true);
      expect(progress, contains((CreationStep.gitInit, LoadingStatus.failed)));
    },
  );

  test('the default language becomes the template ARB file', () async {
    final runner = FakeToolsRunner();

    final created = await serviceFor(
      runner,
    ).create(request(languages: {'en', 'es'}, defaultLanguage: 'es'), record);

    expect(created, true);
    final project = '${parent.path}/demo';
    expect(
      File('$project/l10n.yaml').readAsStringSync(),
      contains('template-arb-file: app_es.arb'),
    );
    final spanish = ArbService.decode(
      File('$project/lib/l10n/app_es.arb').readAsStringSync(),
    )!;
    expect(spanish['@@locale'], 'es');
    expect(spanish, contains('appTitle'));
    expect(
      runner.commands.where((command) => command == 'flutter gen-l10n'),
      hasLength(2),
    );
  });

  test('English stays the template without an l10n.yaml', () async {
    final runner = FakeToolsRunner();

    await serviceFor(runner).create(request(languages: {'en', 'fr'}), record);

    expect(File('${parent.path}/demo/l10n.yaml').existsSync(), false);
  });

  test('AI generation describes the app in the user\'s words', () async {
    final model = FakeChatModel();

    final created = await serviceFor(
      FakeToolsRunner(),
      model,
    ).create(request(useAi: true, description: 'A recipe book'), record);

    expect(created, true);
    expect(model.prompts.single, contains('"A recipe book"'));
    final project = '${parent.path}/demo';
    expect(
      File('$project/pubspec.yaml').readAsStringSync(),
      contains('description: "A recipe book"'),
    );
    expect(
      File('$project/README.md').readAsStringSync(),
      startsWith('# demo\n\nA recipe book'),
    );
  });

  test('outcomes tell failures apart and steps count from one', () {
    expect(CreationOutcome.gitFailed.status, LoadingStatus.failed);
    expect(CreationOutcome.error.isFailure, isTrue);
    expect(CreationOutcome.verified.status, LoadingStatus.success);
    expect(CreationStep.validate.number, 1);
    expect(CreationStep.verification.number, CreationStep.values.length);
    const report = CreationReport(
      CreationStep.codegen,
      CreationOutcome.aiFailed,
      detail: 'offline',
    );
    expect((report.status, report.detail), (LoadingStatus.success, 'offline'));
  });
}
