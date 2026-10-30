import 'dart:async';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:path/path.dart' as p;

/// Receives each creation step's progress as it changes.
typedef CreationProgress = void Function(int, String, LoadingStatus);

/// Creates a new Flutter project: `flutter create`, localization, optional AI
/// starter code, Git and a final check, reporting progress per step.
class ProjectCreationService {
  /// Platforms every new project targets.
  static const String _platforms = 'android,ios,web,linux,macos,windows';

  /// Language whose ARB template `LocalizationService` already writes.
  static const String _templateLanguage = 'en';

  /// Generated files copied into the project, relative to its root.
  static const List<String> _generatedFiles = [
    'pubspec.yaml',
    'lib/main.dart',
    'README.md',
  ];

  /// Entries every created project must have to pass verification.
  static const List<String> _requiredFiles = ['pubspec.yaml', 'lib/main.dart'];
  static const List<String> _requiredDirectories = ['android', 'ios'];

  final ProcessRunner _runner;
  final GitService _git;
  final LocalizationService _localization;
  final AIService _ai;

  /// Creates the service from the tools each step needs.
  const ProjectCreationService(
    this._runner,
    this._git,
    this._localization,
    this._ai,
  );

  /// The creation steps, all pending, for the progress list.
  static List<LoadingAction> initialActions() => [
    LoadingAction(
      AppMetric.projectCreateStepValidate,
      'Validating settings and checking dependencies...',
      LoadingStatus.pending,
    ),
    LoadingAction(
      AppMetric.projectCreateStepFlutterCreate,
      'Creating Flutter project...',
      LoadingStatus.pending,
    ),
    LoadingAction(
      AppMetric.projectCreateStepLocalization,
      'Setting up localization...',
      LoadingStatus.pending,
    ),
    LoadingAction(
      AppMetric.projectCreateStepCodegen,
      'Generating initial code structure...',
      LoadingStatus.pending,
    ),
    LoadingAction(
      AppMetric.projectCreateStepGitInit,
      'Initializing Git repository...',
      LoadingStatus.pending,
    ),
    LoadingAction(
      AppMetric.projectCreateStepVerification,
      'Final verification and cleanup...',
      LoadingStatus.pending,
    ),
  ];

  /// Runs every step for [request]; true when the project was created.
  ///
  /// A failing step is reported as failed through [onProgress] and stops
  /// creation; AI and Git problems are reported but don't stop it.
  Future<bool> create(
    ProjectCreationRequest request,
    CreationProgress onProgress,
  ) async {
    var currentStep = AppMetric.projectCreateStepValidate;
    void report(int step, String text, [LoadingStatus? status]) {
      currentStep = step;
      onProgress(step, text, status ?? LoadingStatus.success);
    }

    try {
      if (!request.flutterAvailable) {
        throw Exception(
          'Flutter is not available. Please install Flutter and restart FIDE.',
        );
      }
      report(
        AppMetric.projectCreateStepValidate,
        'Dependencies validated successfully',
      );

      currentStep = AppMetric.projectCreateStepFlutterCreate;
      await _flutterCreate(request);
      report(currentStep, 'Flutter project created successfully');

      currentStep = AppMetric.projectCreateStepLocalization;
      report(currentStep, await _setUpLocalization(request));

      currentStep = AppMetric.projectCreateStepCodegen;
      report(currentStep, await _generateCode(request));

      currentStep = AppMetric.projectCreateStepGitInit;
      await _initGit(request, report);

      currentStep = AppMetric.projectCreateStepVerification;
      if (!await _isComplete(request.projectPath)) {
        throw Exception(
          'Project verification failed - missing required files/directories',
        );
      }
      report(currentStep, 'Project verification completed successfully');
      return true;
    } catch (e) {
      report(currentStep, 'Error: $e', LoadingStatus.failed);
      return false;
    }
  }

  /// Runs `flutter create`, throwing with its stderr on failure.
  Future<void> _flutterCreate(ProjectCreationRequest request) async {
    final result = await _runner
        .run('flutter', [
          'create',
          '--project-name',
          request.name,
          '--platforms',
          _platforms,
          request.projectPath,
        ], workingDirectory: request.parentDirectory)
        .timeout(
          AppDuration.projectCreateTimeout,
          onTimeout: () =>
              ProcessResult(0, -1, '', 'Flutter create command timed out'),
        );
    if (result.exitCode != 0) {
      throw Exception('Failed to create Flutter project: ${result.stderr}');
    }
  }

  /// Replaces template files with AI-generated ones when requested.
  Future<String> _generateCode(ProjectCreationRequest request) async {
    if (!request.useAi) return 'AI not available, using default structure';
    try {
      final baseDescription = request.languages != null
          ? 'a Flutter app with localization support using provider for state management'
          : 'a Flutter app using provider for state management';
      final description =
          '$baseDescription with the name "${request.name}". Include proper project structure, basic routing, and theme configuration.';

      final generated = await _ai
          .generateProject(request.name, description)
          .timeout(AppDuration.aiProjectCreateTimeout);
      for (final relativePath in _generatedFiles) {
        final content = generated[relativePath];
        if (content != null) {
          await File(p.join(request.projectPath, relativePath))
              .writeAsString(content);
        }
      }
      return 'AI-generated project files completed';
    } on AiServiceException catch (e) {
      return 'AI code generation failed: $e';
    } on TimeoutException {
      return 'AI generation timed out';
    } catch (_) {
      return 'AI code generation failed, using defaults';
    }
  }

  /// Creates the repository when requested, reporting failure without
  /// stopping creation.
  Future<void> _initGit(
    ProjectCreationRequest request,
    void Function(int, String, [LoadingStatus?]) report,
  ) async {
    const step = AppMetric.projectCreateStepGitInit;
    if (!request.initGit) {
      report(step, 'Git not available, skipped');
    } else if (await _git.initWithInitialCommit(request.projectPath)) {
      report(step, 'Git repository initialized');
    } else {
      report(step, 'Git initialization failed', LoadingStatus.failed);
    }
  }

  /// Whether the files and folders every Flutter project has are present.
  Future<bool> _isComplete(String projectPath) async {
    for (final file in _requiredFiles) {
      if (!await File(p.join(projectPath, file)).exists()) return false;
    }
    for (final directory in _requiredDirectories) {
      if (!await Directory(p.join(projectPath, directory)).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Sets up localization and an empty ARB file for each extra language.
  Future<String> _setUpLocalization(ProjectCreationRequest request) async {
    final languages = request.languages;
    if (languages == null) return 'Localization skipped';

    await _localization.initializeLocalization(
      request.projectPath,
      tolerateToolFailures: true,
    );
    for (final language in languages) {
      if (language == _templateLanguage) continue;
      final arb = File(
        p.join(request.projectPath, 'lib', 'l10n', 'app_$language.arb'),
      );
      if (!await arb.exists()) await arb.writeAsString('{}\n');
    }
    return 'Localization setup completed';
  }
}
