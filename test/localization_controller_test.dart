import 'dart:async';
import 'dart:io';

import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/localization_status.dart';
import 'package:fide/providers/localization_controller.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks for a fully set up project.
const LocalizationChecks _complete = LocalizationChecks(
  hasPubspec: true,
  isFlutterProject: true,
  hasArbFiles: true,
  hasGeneratedClasses: true,
  hasAppIntegration: true,
  hasDependencies: true,
  hasGenerateFlag: true,
);

/// Holds the fakes' actions until [gate] completes, and makes them throw
/// [failure].
class FakeActions {
  Completer<void>? gate;
  Object? failure;

  Future<void> act() async {
    await gate?.future;
    if (failure case final error?) throw error;
  }
}

/// Answers [inspect] with [checks], counting calls; its actions run
/// through [actions].
class FakeLocalizationSetup extends LocalizationSetup {
  FakeLocalizationSetup(this.actions)
    : super(
        const ProcessRunner(),
        const ProjectConfigReader(),
        const L10nGenerator(ProcessRunner()),
      );

  final FakeActions actions;
  LocalizationChecks checks = _complete;
  int inspections = 0;

  @override
  Future<LocalizationChecks> inspect(String projectPath) async {
    inspections++;
    return checks;
  }

  @override
  Future<String> wireApp(String projectPath) async {
    await actions.act();
    return 'lib/main.dart';
  }

  @override
  Future<void> initializeLocalization(
    String projectPath, {
    ProcessOutputCallback? onStep,
    bool tolerateToolFailures = false,
    Set<String> locales = LocalizationSetup.starterLocales,
  }) => actions.act();

  @override
  Future<String> addLocale(String projectPath, String locale) async {
    await actions.act();
    final path = '$projectPath/lib/l10n/app_$locale.arb';
    File(path).writeAsStringSync('{}');
    return path;
  }

  @override
  Future<String> removeLocale(String projectPath, String locale) async {
    await actions.act();
    final path = '$projectPath/lib/l10n/app_$locale.arb';
    File(path).deleteSync();
    return path;
  }
}

/// Generates nothing: runs through [actions].
class FakeL10nGenerator extends L10nGenerator {
  const FakeL10nGenerator(this.actions) : super(const ProcessRunner());

  final FakeActions actions;

  @override
  Future<void> generateClasses(String projectPath) => actions.act();
}

void main() {
  late Directory project;
  late FakeActions actions;
  late FakeLocalizationSetup service;
  late LocalizationController controller;
  late List<String> reloaded;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_l10n_ctrl_');
    Directory('${project.path}/lib/l10n').createSync(recursive: true);
    File('${project.path}/lib/l10n/app_en.arb').writeAsStringSync(
      '{"hello": "Hello", "hi": "Hello", '
      '"@hi": {"description": "A greeting"}}',
    );
    File('${project.path}/lib/l10n/app_fr.arb')
        .writeAsStringSync('{"hello": "Bonjour"}');
    actions = FakeActions();
    service = FakeLocalizationSetup(actions);
    reloaded = [];
    controller = LocalizationController(
      project.path,
      setup: service,
      generator: FakeL10nGenerator(actions),
      arb: const ArbService(),
      reloadWritten: (paths) async => reloaded.addAll(paths),
    );
  });

  tearDown(() {
    controller.dispose();
    project.deleteSync(recursive: true);
  });

  test('reload inspects once and loads the ARB files', () async {
    await controller.reload();

    expect(service.inspections, 1);
    expect(controller.state.status, LocalizationStatus.complete);
    expect(controller.state.arbFiles, hasLength(2));
    expect(controller.state.comparisons, hasLength(2));
    expect(controller.state.isBusy, false);
  });

  test('an action is busy while running and idle after success', () async {
    actions.gate = Completer<void>();
    final outcome = controller.wireApp();

    expect(controller.state.isBusy, true);
    actions.gate!.complete();

    expect((await outcome)!.succeeded, true);
    expect(controller.state.isBusy, false);
    expect(controller.state.status, LocalizationStatus.complete);
  });

  test('an action clears busy after a failure', () async {
    actions.failure = Exception('boom');

    final outcome = await controller.generateClasses();

    expect(outcome!.succeeded, false);
    expect(outcome.message, contains('boom'));
    expect(controller.state.isBusy, false);
  });

  test('generation without the generate flag fails and clears busy', () async {
    service.checks = const LocalizationChecks(
      hasPubspec: true,
      isFlutterProject: true,
      hasArbFiles: true,
      hasGeneratedClasses: false,
      hasAppIntegration: false,
      hasDependencies: true,
      hasGenerateFlag: false,
    );

    final outcome = await controller.generateClasses();

    expect(outcome!.message, LocalizationController.missingGenerateFlag);
    expect(controller.state.isBusy, false);
  });

  test('initialize reports its steps and clears busy', () async {
    final steps = <String>[];

    final outcome = await controller.initialize(onStep: steps.add);

    expect(outcome!.succeeded, true);
    expect(steps, isNotEmpty);
    expect(controller.state.isBusy, false);
  });

  test('a missing language translates into its ARB file', () async {
    await controller.reload();
    final missing = controller.state.comparisons.firstWhere(
      (comparison) => comparison.key == 'hi',
    );

    final translation = controller.translationOf(missing, 'fr');

    expect(translation!.key, 'hi');
    expect(translation.language, 'French');
    expect(translation.description, 'A greeting');
    expect(translation.arbPath, endsWith('app_fr.arb'));
    expect(controller.translationOf(missing, 'xx'), isNull);
  });

  test('an added locale reloads with every key to translate', () async {
    await controller.reload();

    final outcome = await controller.addLocale('de');

    expect(outcome!.succeeded, true);
    expect(reloaded.single, endsWith('app_de.arb'));
    expect(controller.state.locales, ['de', 'en', 'fr']);
    expect(controller.state.templateLocale, 'en');
    expect([
      for (final t in controller.translationsInto('de')) t.key,
    ], unorderedEquals(['hello', 'hi']));
    expect(controller.state.isBusy, false);
  });

  test('a removed locale reloads without it', () async {
    await controller.reload();

    final outcome = await controller.removeLocale('fr');

    expect(outcome!.succeeded, true);
    expect(controller.state.locales, ['en']);
  });

  test('without a project, actions do nothing', () async {
    final idle = LocalizationController(
      null,
      setup: service,
      generator: FakeL10nGenerator(actions),
      arb: const ArbService(),
      reloadWritten: (_) async {},
    );
    addTearDown(idle.dispose);

    expect(await idle.wireApp(), isNull);
    expect(idle.state.status, LocalizationStatus.checking);
  });

  group('LocalizationChecks.status', () {
    LocalizationChecks checks({
      bool hasPubspec = true,
      bool isFlutterProject = true,
      bool hasArbFiles = false,
      bool hasGeneratedClasses = false,
      bool hasAppIntegration = false,
    }) => LocalizationChecks(
      hasPubspec: hasPubspec,
      isFlutterProject: isFlutterProject,
      hasArbFiles: hasArbFiles,
      hasGeneratedClasses: hasGeneratedClasses,
      hasAppIntegration: hasAppIntegration,
      hasDependencies: false,
      hasGenerateFlag: false,
    );

    test('summarises the checks', () {
      expect(checks(hasPubspec: false).status, LocalizationStatus.noProject);
      expect(
        checks(isFlutterProject: false).status,
        LocalizationStatus.notFlutterProject,
      );
      expect(checks().status, LocalizationStatus.notStarted);
      expect(checks(hasArbFiles: true).status, LocalizationStatus.partial);
      expect(
        checks(hasGeneratedClasses: true).status,
        LocalizationStatus.partial,
      );
      expect(_complete.status, LocalizationStatus.complete);
    });

    test('the state reports checking, then error over the checks', () {
      expect(LocalizationState.initial.status, LocalizationStatus.checking);
      expect(
        const LocalizationState(checks: _complete, checkFailed: true).status,
        LocalizationStatus.error,
      );
    });
  });

  test('ArbComparison.matches looks at the key and every value', () {
    final comparison = ArbComparison(
      key: 'greeting',
      englishValue: 'Hello',
      otherValues: {'fr': 'Bonjour', 'de': null},
    );

    expect(comparison.matches(''), true);
    expect(comparison.matches('GREET'), true);
    expect(comparison.matches('hell'), true);
    expect(comparison.matches('jour'), true);
    expect(comparison.matches('hola'), false);
  });

  test('ArbService.duplicatedEnglishValues finds shared values', () {
    ArbComparison entry(String key, String? english) =>
        ArbComparison(key: key, englishValue: english, otherValues: const {});

    expect(
      ArbService.duplicatedEnglishValues([
        entry('a', 'Save'),
        entry('b', 'Save'),
        entry('c', 'Cancel'),
        entry('d', null),
      ]),
      {'Save'},
    );
  });
}
