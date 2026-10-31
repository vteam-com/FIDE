import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/lookup_plan.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/providers/arb_key_remover.dart';
import 'package:fide/providers/arb_migrator.dart';
import 'package:fide/providers/arb_translator.dart';
import 'package:fide/providers/code_review.dart';
import 'package:fide/providers/string_constants_extractor.dart';
import 'package:fide/providers/string_localizer.dart';
import 'package:fide/providers/string_lookup_passer.dart';
import 'package:path/path.dart' as p;

/// What a quick fix did: one line for the user and the files it wrote.
typedef QuickFixOutcome = ({String summary, List<String> changedFiles});

/// Asks the user to confirm [fix], explained by [message].
typedef QuickFixConfirmation = Future<bool> Function(
  QuickFix fix,
  String message,
);

/// Runs a [QuickFix] on a project from a fresh fCheck analysis, for the
/// issue dialogs and for the AI, which calls it through a hook.
///
/// The dialogs pass a [QuickFixConfirmation] and review hardcoded strings
/// through [reviewStrings] and [applyStrings]; without them, a fix runs
/// unasked and rewrites only the strings of its [QuickFix.stringRole].
class QuickFixRunner {
  /// Creates a runner over the services each fix uses.
  const QuickFixRunner({
    required this.review,
    required this.localizer,
    required this.lookups,
    required this.extractor,
    required this.translator,
    required this.migrator,
    required this.keyRemover,
  });

  /// Makes data-id strings constants.
  final StringConstantsExtractor extractor;

  /// Localizes strings.
  final StringLocalizer localizer;

  /// Localizes strings through the widget fields they are passed to.
  final StringLookupPasser lookups;

  /// Migrates Dart-written translations to ARB.
  final ArbMigrator migrator;

  /// Analyzes the project with fCheck.
  final CodeReview review;

  /// Translates ARB keys.
  final ArbTranslator translator;

  /// Removes unused ARB keys.
  final ArbKeyRemover keyRemover;

  /// What localizing and making constants would do to the hardcoded
  /// strings of the project at [projectPath], from a fresh analysis.
  Future<StringReview> reviewStrings(String projectPath) async =>
      _reviewStrings(projectPath, await review.analyze(projectPath));

  /// Rewrites the [selected] strings of [strings] with [fix], one of the
  /// fixes with a [QuickFix.stringRole].
  Future<QuickFixOutcome> applyStrings(
    StringReview strings,
    QuickFix fix,
    List<HardcodedString> selected,
  ) async {
    final StringRewrite result;
    switch (fix) {
      case QuickFix.localizeStrings:
        final plan = strings.localization;
        if (plan == null) throw Exception(strings.localizationBlocker);
        result = await localizer.apply(plan, selected);
      case QuickFix.passLookup:
        final plan = strings.localization;
        if (plan == null) throw Exception(strings.localizationBlocker);
        result = await lookups.apply(plan, strings.lookups, selected);
      case QuickFix.makeConstants:
        result = await extractor.apply(strings.constants, selected);
      default:
        throw ArgumentError.value(fix, 'fix', 'rewrites no strings');
    }
    return (summary: result.summary, changedFiles: result.changedFiles);
  }

  /// Applies [fix] to the project at [projectPath], telling [onProgress]
  /// about long steps; null when the user cancels through [confirm].
  Future<QuickFixOutcome?> run(
    String projectPath,
    QuickFix fix, {
    QuickFixConfirmation? confirm,
    void Function(String)? onProgress,
  }) async {
    // Fresh analysis: the files may have changed since the overview
    final metrics = await review.analyze(projectPath);
    Future<bool> confirmed(String message) async =>
        await confirm?.call(fix, message) ?? true;

    switch (fix) {
      case QuickFix.localizeStrings ||
          QuickFix.passLookup ||
          QuickFix.makeConstants:
        final strings = await _reviewStrings(projectPath, metrics);
        return applyStrings(strings, fix, strings.withRole(fix.stringRole!));
      case QuickFix.removeUnusedKeys:
        final keys = ArbKeyRemover.unusedKeys(metrics);
        if (keys.isEmpty) {
          return (summary: 'No unused keys', changedFiles: <String>[]);
        }
        if (!await confirmed(
          '${keys.join(', ')} ${keys.length == 1 ? 'is' : 'are'} not used '
          'by the code: each is removed from every ARB file with its '
          'metadata, and the classes are regenerated.',
        )) {
          return null;
        }
        final result = await keyRemover.apply(projectPath, keys);
        return (summary: result.summary, changedFiles: result.changedFiles);
      case QuickFix.translateKeys:
        final translations = await translator.plan(projectPath, metrics);
        if (translations.isEmpty) {
          return (summary: 'Nothing to translate', changedFiles: <String>[]);
        }
        final languages = {for (final t in translations) t.language};
        if (!await confirmed(
          'The local model translates ${translations.length.localized} keys '
          'into ${languages.join(', ')} in short batches, keeping every '
          '{placeholder}; FIDE writes the ARB files and regenerates the '
          'classes.',
        )) {
          return null;
        }
        final result = await translator.apply(
          projectPath,
          translations,
          onProgress: onProgress,
        );
        return (summary: result.summary, changedFiles: result.changedFiles);
      case QuickFix.migrateToArb:
        final sync = metrics.localizationSync;
        if (sync == null || sync.isInSync) {
          return (summary: 'Already migrated to ARB', changedFiles: <String>[]);
        }
        final moved = sync.handWrittenMembers;
        if (!await confirmed(
          'Every translation in ${p.basename(sync.generatedFilePath)} and its '
          'locale files moves to the ARB files, '
          '${moved.isEmpty ? '' : '${moved.join(', ')} move to their own file, '}'
          'and flutter gen-l10n regenerates the classes. If the project ends '
          'up with more analyzer errors, every file is restored.',
        )) {
          return null;
        }
        final result = await migrator.migrate(projectPath, sync);
        return (summary: result.summary, changedFiles: result.changedFiles);
    }
  }

  /// [reviewStrings] from [metrics].
  Future<StringReview> _reviewStrings(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    LocalizationPlan? localization;
    String? blocker;
    try {
      localization = await localizer.plan(projectPath, metrics);
    } on Exception catch (e) {
      blocker = '$e'.replaceFirst('Exception: ', '');
    }
    return StringReview(
      localization: localization,
      localizationBlocker: blocker,
      lookups: localization == null
          ? const LookupPlan()
          : await lookups.plan(localization),
      constants: await extractor.plan(projectPath, metrics),
    );
  }
}
