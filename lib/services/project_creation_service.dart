import 'dart:async';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/creation_outcome.dart';
import 'package:fide/models/creation_report.dart';
import 'package:fide/models/creation_step.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_template.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

/// Receives each creation step's report as it ends.
typedef CreationProgress = void Function(CreationReport report);

/// Creates a new Flutter project: `flutter create`, localization, optional AI
/// starter code, Git and a final check, reporting each [CreationStep]'s
/// [CreationOutcome]; the wizard words them.
class ProjectCreationService {
  /// Language whose ARB template `LocalizationSetup` already writes.
  static const String _templateLanguage =
      ProjectCreationRequest.englishLanguage;

  /// gen-l10n settings of a new project, whose ARB files stay in Flutter's
  /// default folder.
  static const L10nConfig _l10n = L10nConfig();

  /// Platform folders every created project must have to pass
  /// verification.
  static const List<FlutterPlatform> _requiredPlatforms = [
    FlutterPlatform.android,
    FlutterPlatform.ios,
  ];

  final ProcessRunner _runner;
  final GitService _git;
  final LocalizationSetup _localization;
  final L10nGenerator _generator;
  final ProjectTemplate _template;

  /// Creates the service from the tools each step needs.
  const ProjectCreationService(
    this._runner,
    this._git,
    this._localization,
    this._generator,
    this._template,
  );

  /// Runs every step for [request]; true when the project was created.
  ///
  /// A failing step is reported as [CreationOutcome.error] through
  /// [onProgress] and stops creation; AI and Git problems are reported but
  /// don't stop it.
  Future<bool> create(
    ProjectCreationRequest request,
    CreationProgress onProgress,
  ) async {
    var currentStep = CreationStep.validate;
    void report(CreationOutcome outcome, [String detail = '']) {
      onProgress(CreationReport(currentStep, outcome, detail: detail));
    }

    try {
      if (!request.flutterAvailable) {
        throw Exception(
          'Flutter is not available. Please install Flutter and restart FIDE.',
        );
      }
      report(CreationOutcome.validated);

      currentStep = CreationStep.flutterCreate;
      await _flutterCreate(request);
      await _describe(request);
      report(CreationOutcome.flutterCreated);

      currentStep = CreationStep.localization;
      report(await _setUpLocalization(request));

      currentStep = CreationStep.codegen;
      final (outcome, detail) = await _generateCode(request);
      report(outcome, detail);

      currentStep = CreationStep.gitInit;
      report(await _initGit(request));

      currentStep = CreationStep.verification;
      if (!await _isComplete(request.projectPath)) {
        throw Exception(
          'Project verification failed - missing required files/directories',
        );
      }
      report(CreationOutcome.verified);
      return true;
    } catch (e) {
      report(CreationOutcome.error, ReadableError.describe(e));
      return false;
    }
  }

  /// Runs `flutter create`, throwing with its stderr on failure.
  Future<void> _flutterCreate(ProjectCreationRequest request) async {
    Exception failure(Object reason) =>
        Exception('Failed to create Flutter project: $reason');
    await _runner
        .runChecked(
          FlutterSdk.executable,
          [
            'create',
            '--project-name',
            request.name,
            '--platforms',
            [for (final platform in FlutterPlatform.values) platform.name]
                .join(','),
            request.projectPath,
          ],
          workingDirectory: request.parentDirectory,
          error: (result) => failure(result.stderr),
        )
        .timeout(
          AppDuration.projectCreateTimeout,
          onTimeout: () => throw failure('Flutter create command timed out'),
        );
  }

  /// Puts the user's description of the app in the `pubspec.yaml` that
  /// `flutter create` wrote, editing only that field.
  Future<void> _describe(ProjectCreationRequest request) async {
    if (request.description.isEmpty) return;
    await ProjectConfigReader.updatePubspec(
      request.projectPath,
      (yaml) => (YamlEditor(
        yaml,
      )..update([Pubspec.descriptionKey], request.description)).toString(),
    );
  }

  /// Replaces template files with AI-generated ones when requested; how
  /// it went, with the AI's error when it failed.
  Future<(CreationOutcome, String)> _generateCode(
    ProjectCreationRequest request,
  ) async {
    if (!request.useAi) return (CreationOutcome.aiNotUsed, '');
    try {
      final description = request.description.isNotEmpty
          ? request.description
          : request.languages != null
          ? 'A Flutter app with localization support using provider for state management.'
          : 'A Flutter app using provider for state management.';

      final generated = await _template
          .generate(request.name, description)
          .timeout(AppDuration.aiProjectCreateTimeout);
      for (final MapEntry(key: relativePath, value: content)
          in generated.entries) {
        await File(p.join(request.projectPath, relativePath))
            .writeAsString(content);
      }
      return (CreationOutcome.aiGenerated, '');
    } on AiServiceException catch (e) {
      return (CreationOutcome.aiFailed, ReadableError.describe(e));
    } on TimeoutException {
      return (CreationOutcome.aiTimedOut, '');
    } catch (_) {
      return (CreationOutcome.aiFailedUsingDefaults, '');
    }
  }

  /// Creates the repository when requested; a failure is reported without
  /// stopping creation.
  Future<CreationOutcome> _initGit(ProjectCreationRequest request) async {
    if (!request.initGit) return CreationOutcome.gitSkipped;
    return await _git.initWithInitialCommit(request.projectPath)
        ? CreationOutcome.gitInitialized
        : CreationOutcome.gitFailed;
  }

  /// Whether the files and folders every Flutter project has are present.
  Future<bool> _isComplete(String projectPath) async {
    final paths = ProjectPaths(projectPath);
    for (final file in [paths.pubspec, paths.mainDart]) {
      if (!await File(file).exists()) return false;
    }
    for (final platform in _requiredPlatforms) {
      if (!await Directory(paths.platformDir(platform)).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Sets up localization with an ARB file for each language, making the
  /// default language the template.
  Future<CreationOutcome> _setUpLocalization(
    ProjectCreationRequest request,
  ) async {
    final languages = request.languages;
    if (languages == null) return CreationOutcome.localizationSkipped;

    await _localization.initializeLocalization(
      request.projectPath,
      tolerateToolFailures: true,
      locales: languages,
    );
    if (request.defaultLanguage != _templateLanguage) {
      await _makeTemplate(request.projectPath, request.defaultLanguage);
    }
    return CreationOutcome.localized;
  }

  /// Makes [language] the template of the project at [projectPath]: gives
  /// its ARB file the starter messages when it has none, points
  /// `l10n.yaml` at it and generates the classes again, so it is the
  /// first supported locale.
  Future<void> _makeTemplate(String projectPath, String language) async {
    final arb = _l10n.arbPathFor(projectPath, language);
    final messages = await ArbService.read(arb);
    final hasMessages = messages?.keys.any(ArbKeys.isMessageKey) ?? false;
    if (!hasMessages) {
      final starter =
          await ArbService.read(
            _l10n.arbPathFor(projectPath, _templateLanguage),
          ) ??
          {};
      await ArbService.write(arb, {...starter, ArbService.localeKey: language});
    }
    // The ARB files stay in Flutter's default folder, where they are
    await File(p.join(projectPath, L10nConfig.fileName))
        .writeAsString('template-arb-file: ${_l10n.arbFileName(language)}\n');
    try {
      await _generator.generateClasses(projectPath);
    } catch (_) {
      // Like the first generation: pub may be offline; the next build
      // generates the classes
    }
  }
}
