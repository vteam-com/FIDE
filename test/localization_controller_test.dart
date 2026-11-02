import 'dart:async';
import 'dart:io';

import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/localization_status.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/providers/localization_controller.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

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

/// Answers [inspect] with [checks], counting calls; [gate] holds the
/// actions until completed, and [failure] makes them throw.
class FakeLocalizationService extends LocalizationService {
  FakeLocalizationService()
    : super(const ProcessRunner(), const ProjectConfigReader());

  LocalizationChecks checks = _complete;
  int inspections = 0;
  Completer<void>? gate;
  Object? failure;

  @override
  Future<LocalizationChecks> inspect(String projectPath) async {
    inspections++;
    return checks;
  }

  @override
  Future<void> updateMainDartForLocalization(String projectPath) => _act();

  @override
  Future<void> generateClasses(String projectPath) => _act();

  @override
  Future<void> initializeLocalization(
    String projectPath, {
    ProcessOutputCallback? onStep,
    bool tolerateToolFailures = false,
  }) => _act();

  Future<void> _act() async {
    await gate?.future;
    if (failure case final error?) throw error;
  }
}

/// Reports every translation as written without asking a model.
class FakeTranslator extends ArbTranslator {
  FakeTranslator()
    : super(
        FakeChatModel(),
        LocalizationService(const ProcessRunner(), const ProjectConfigReader()),
      );

  final List<ArbTranslation> applied = [];

  @override
  Future<StringRewrite> apply(
    String projectPath,
    List<ArbTranslation> translations, {
    AiCancelToken? cancel,
    void Function(String)? onProgress,
  }) async {
    applied.addAll(translations);
    return StringRewrite(
      action: 'Translated',
      rewritten: translations.length,
      changedFiles: const [],
      skipped: const {},
    );
  }
}

void main() {
  late Directory project;
  late FakeLocalizationService service;
  late FakeTranslator translator;
  late LocalizationController controller;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_l10n_ctrl_');
    Directory('${project.path}/lib/l10n').createSync(recursive: true);
    File('${project.path}/lib/l10n/app_en.arb')
        .writeAsStringSync('{"hello": "Hello", "hi": "Hello"}');
    File('${project.path}/lib/l10n/app_fr.arb')
        .writeAsStringSync('{"hello": "Bonjour"}');
    service = FakeLocalizationService();
    translator = FakeTranslator();
    controller = LocalizationController(
      project.path,
      localization: service,
      arb: ArbService(),
      translator: translator,
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
    service.gate = Completer<void>();
    final outcome = controller.updateMainDart();

    expect(controller.state.isBusy, true);
    service.gate!.complete();

    expect((await outcome)!.succeeded, true);
    expect(controller.state.isBusy, false);
    expect(controller.state.status, LocalizationStatus.complete);
  });

  test('an action clears busy after a failure', () async {
    service.failure = Exception('boom');

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

  test('translate writes the missing language and reloads', () async {
    await controller.reload();
    final missing = controller.state.comparisons.firstWhere(
      (comparison) => comparison.key == 'hi',
    );

    final outcome = await controller.translate(missing, 'fr');

    expect(outcome!.succeeded, true);
    expect(translator.applied.single.arbPath, endsWith('app_fr.arb'));
    expect(controller.state.isBusy, false);
  });

  test('without a project, actions do nothing', () async {
    final idle = LocalizationController(
      null,
      localization: service,
      arb: ArbService(),
      translator: translator,
    );
    addTearDown(idle.dispose);

    expect(await idle.updateMainDart(), isNull);
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
