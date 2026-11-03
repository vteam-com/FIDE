import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';

/// The Localization panel's state for the open project, inspected when the
/// panel opens and reloaded when the string issues change, e.g. after
/// Localize strings rewrote the ARB files.
final localizationControllerProvider =
    StateNotifierProvider.autoDispose<
      LocalizationController,
      LocalizationState
    >((ref) {
      final projectPath = ref.watch(
        currentProjectRootProvider.select((root) => root?.path),
      );
      final controller = LocalizationController(
        projectPath,
        setup: ref.read(localizationSetupProvider),
        generator: ref.read(l10nGeneratorProvider),
        arb: ref.read(arbServiceProvider),
        translator: ref.read(arbTranslatorProvider),
      );
      ref.listen(stringIssuesProvider, (previous, next) {
        if (previous != null && next != null) controller.reload();
      });
      controller.reload();
      return controller;
    });

/// Inspects a project's localization setup, loads its ARB files and runs
/// the Localization panel's actions, each marking the state busy until it
/// ends, whether it succeeds or fails.
class LocalizationController extends StateNotifier<LocalizationState> {
  static final Logger _logger = Logger('LocalizationController');

  /// Message for a generation attempted without `generate: true`.
  static const String missingGenerateFlag =
      'Cannot generate localization classes. Please ensure your pubspec.yaml '
      'has "generate: true" properly indented under the flutter section, run '
      '"flutter pub get", and restart your IDE. Example:\n\nflutter:\n  '
      'generate: true\n  uses-material-design: true';

  final ArbService _arb;

  final L10nGenerator _generator;

  final LocalizationSetup _setup;

  /// The open project, or null.
  final String? _projectPath;

  final ArbTranslator _translator;

  /// Creates a controller for the project at [_projectPath].
  LocalizationController(
    this._projectPath, {
    required this._setup,
    required this._generator,
    required this._arb,
    required this._translator,
  }) : super(LocalizationState.initial);

  /// Generates the localization classes with `flutter gen-l10n`, once the
  /// pubspec enables code generation.
  Future<ActionOutcome?> generateClasses() {
    return _run('Error generating classes', (projectPath) async {
      final checks = await _setup.inspect(projectPath);
      if (!checks.hasGenerateFlag) {
        return const ActionOutcome.failure(missingGenerateFlag);
      }
      await _generator.generateClasses(projectPath);
      await reload();
      return const ActionOutcome.success(
        'Localization classes generated successfully!',
      );
    });
  }

  /// Sets localization up and wires it into `main.dart`; [onStep] is told
  /// about each step.
  Future<ActionOutcome?> initialize({ProcessOutputCallback? onStep}) {
    return _run('Error initializing localization', (projectPath) async {
      await _setup.initializeLocalization(projectPath, onStep: onStep);
      onStep?.call('Updating main.dart...');
      await _setup.updateMainDartForLocalization(projectPath);
      await reload();
      return const ActionOutcome.success(
        'Localization system initialized and main.dart updated successfully!',
      );
    });
  }

  /// Inspects the project's localization setup, then loads its ARB files.
  Future<void> reload() async {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    try {
      final checks = await _setup.inspect(projectPath);
      _update((state) => state.copyWith(checks: checks, checkFailed: false));
    } catch (e) {
      _logger.severe('Error checking localization status: $e');
      _update((state) => state.copyWith(checkFailed: true));
    }
    await _loadArbFiles(projectPath);
  }

  /// Translates [comparison]'s English value into [language] with the
  /// shared [ArbTranslator], writing it to that language's ARB file.
  Future<ActionOutcome?> translate(ArbComparison comparison, String language) {
    return _run('Error translating', (projectPath) async {
      final source = comparison.englishValue;
      final target = state.arbFiles
          .where((file) => file.languageCode == language)
          .firstOrNull;
      if (source == null || target == null) {
        return ActionOutcome.failure(
          'Nothing to translate for "${comparison.key}" into $language',
        );
      }
      final result = await _translator.apply(projectPath, [
        ArbTranslation(
          key: comparison.key,
          source: source,
          language: language,
          arbPath: target.path,
        ),
      ]);
      await reload();
      return result.rewritten > 0
          ? ActionOutcome.success('Translated "${comparison.key}" to $language')
          : ActionOutcome.failure('Translation failed: ${result.summary}');
    });
  }

  /// Wires the generated localizations into `main.dart`.
  Future<ActionOutcome?> updateMainDart() {
    return _run('Error updating main.dart', (projectPath) async {
      await _setup.updateMainDartForLocalization(projectPath);
      await reload();
      return const ActionOutcome.success('main.dart updated successfully!');
    });
  }

  /// Loads and compares the ARB files of the project at [projectPath].
  Future<void> _loadArbFiles(String projectPath) async {
    try {
      final arbFiles = await _arb.loadArbFiles(
        ProjectPaths(projectPath).l10nDir,
      );
      _update(
        (state) => state.copyWith(
          arbFiles: arbFiles.valid,
          comparisons: _arb.compareArbFiles(arbFiles.valid),
          malformedArbFiles: arbFiles.malformed,
          clearLoadError: true,
        ),
      );
    } catch (e) {
      _update(
        (state) => state.copyWith(loadError: 'Error loading ARB files: $e'),
      );
    }
  }

  /// Runs [action] on the open project with the state busy, turning a
  /// thrown error into a failure prefixed by [failurePrefix]; null when no
  /// project is open.
  Future<ActionOutcome?> _run(
    String failurePrefix,
    Future<ActionOutcome> Function(String projectPath) action,
  ) async {
    final projectPath = _projectPath;
    if (projectPath == null) return null;
    _update((state) => state.copyWith(isBusy: true));
    try {
      return await action(projectPath);
    } catch (e) {
      return ActionOutcome.failure('$failurePrefix: $e');
    } finally {
      _update((state) => state.copyWith(isBusy: false));
    }
  }

  /// Applies [change] to the state, unless the controller was disposed
  /// while an operation was pending.
  void _update(LocalizationState Function(LocalizationState state) change) {
    if (mounted) state = change(state);
  }
}
