import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/language_catalog.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/arb_service.dart';
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
        reloadWritten: ref.read(openDocumentsProvider.notifier).reloadWritten,
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
class LocalizationController extends StateNotifier<LocalizationState>
    with ProjectActions<LocalizationState> {
  static final Logger _logger = Logger('LocalizationController');

  /// Message for a generation attempted without `generate: true`.
  static const String missingGenerateFlag =
      'Cannot generate localization classes. Please ensure your pubspec.yaml '
      'has "generate: true" properly indented under the flutter section, run '
      '"flutter pub get", and restart your IDE. Example:\n\nflutter:\n  '
      'generate: true\n  uses-material-design: true';

  final ArbService _arb;

  final L10nGenerator _generator;

  final ReloadWritten _reloadWritten;

  final LocalizationSetup _setup;

  @override
  final String? projectPath;

  /// Creates a controller for the project at [projectPath], reloading the
  /// ARB files it adds or removes with [_reloadWritten], which refreshes
  /// the views derived from them.
  LocalizationController(
    this.projectPath, {
    required this._setup,
    required this._generator,
    required this._arb,
    required this._reloadWritten,
  }) : super(LocalizationState.initial);

  /// Adds [locale] to the project, as [LocalizationSetup.addLocale] does,
  /// and reloads.
  Future<ActionOutcome?> addLocale(String locale) => _changeLocale(
    locale,
    _setup.addLocale,
    failure: 'Error adding',
    success: 'Added',
  );

  /// Generates the localization classes with `flutter gen-l10n`, once the
  /// pubspec enables code generation.
  Future<ActionOutcome?> generateClasses() {
    return runAction('Error generating classes', _busy, (projectPath) async {
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

  /// Sets localization up and wires it into the app widget; [onStep] is
  /// told about each step.
  Future<ActionOutcome?> initialize({ProcessOutputCallback? onStep}) {
    return runAction('Error initializing localization', _busy, (
      projectPath,
    ) async {
      await _setup.initializeLocalization(projectPath, onStep: onStep);
      onStep?.call('Wiring the app…');
      final appFile = await _setup.wireApp(projectPath);
      await reload();
      return ActionOutcome.success(
        'Localization system initialized and $appFile updated successfully!',
      );
    });
  }

  /// Inspects the project's localization setup, then loads its ARB files.
  Future<void> reload() async {
    final projectPath = this.projectPath;
    if (projectPath == null) return;
    try {
      final checks = await _setup.inspect(projectPath);
      updateState(
        (state) => state.copyWith(checks: checks, checkFailed: false),
      );
    } catch (e) {
      _logger.severe('Error checking localization status: $e');
      updateState((state) => state.copyWith(checkFailed: true));
    }
    await _loadArbFiles(projectPath);
  }

  /// Removes [locale] from the project, as
  /// [LocalizationSetup.removeLocale] does, and reloads.
  Future<ActionOutcome?> removeLocale(String locale) => _changeLocale(
    locale,
    _setup.removeLocale,
    failure: 'Error removing',
    success: 'Removed',
  );

  /// The translation of [comparison]'s template value into [locale],
  /// written to that locale's ARB file, with the template's description of
  /// the key; null when there is no template value or no ARB file for
  /// [locale].
  ArbTranslation? translationOf(ArbComparison comparison, String locale) {
    final source = comparison.englishValue;
    final target = state.arbFileOf(locale);
    if (source == null || target == null) return null;
    return ArbTranslation(
      key: comparison.key,
      source: source,
      description: comparison.description,
      language: LanguageCatalog.nameOf(locale),
      arbPath: target.path,
    );
  }

  /// Wires the generated localizations into the app widget.
  Future<ActionOutcome?> wireApp() {
    return runAction('Error wiring the app', _busy, (projectPath) async {
      final appFile = await _setup.wireApp(projectPath);
      await reload();
      return ActionOutcome.success('$appFile updated successfully!');
    });
  }

  /// Runs [change] of [locale]'s ARB file, which returns the file's path,
  /// as an action ending in [success] or [failure] followed by the
  /// locale's label, then reloads the file in the editor and the panel.
  Future<ActionOutcome?> _changeLocale(
    String locale,
    Future<String> Function(String projectPath, String locale) change, {
    required String failure,
    required String success,
  }) {
    final label = LanguageCatalog.labelOf(locale);
    return runAction('$failure $label', _busy, (projectPath) async {
      await _reloadWritten([await change(projectPath, locale)]);
      await reload();
      return ActionOutcome.success('$success $label');
    });
  }

  /// Loads and compares the ARB files of the project at [projectPath].
  Future<void> _loadArbFiles(String projectPath) async {
    try {
      final arbFiles = await _arb.loadProject(projectPath);
      updateState(
        (state) => state.copyWith(
          arbFiles: arbFiles.valid,
          comparisons: arbFiles.comparisons,
          malformedArbFiles: arbFiles.malformed,
          templateLocale: arbFiles.templateLocale,
          clearLoadError: true,
        ),
      );
    } catch (e) {
      updateState(
        (state) => state.copyWith(
          loadError: 'Error loading ARB files: ${ReadableError.describe(e)}',
        ),
      );
    }
  }

  /// Marks the state busy or idle.
  static LocalizationState _busy(LocalizationState state, bool busy) =>
      state.copyWith(isBusy: busy);
}
