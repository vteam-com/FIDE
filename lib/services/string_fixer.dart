import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/lookup_plan.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/string_constants_extractor.dart';
import 'package:fide/services/string_localizer.dart';
import 'package:fide/services/string_lookup_passer.dart';

/// Reviews a project's hardcoded strings and rewrites the ones the user
/// picks with a [StringFix]: localizing them, passing lookups to widget
/// fields, or making them constants.
class StringFixer {
  /// Creates a fixer over the services each [StringFix] uses.
  const StringFixer({
    required this.localizer,
    required this.lookups,
    required this.extractor,
  });

  /// Makes data-id strings constants.
  final StringConstantsExtractor extractor;

  /// Localizes strings.
  final StringLocalizer localizer;

  /// Localizes strings through the widget fields they are passed to.
  final StringLookupPasser lookups;

  /// What each [StringFix] would do to the hardcoded strings of the
  /// project at [projectPath], analyzed as [metrics].
  Future<StringReview> review(
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

  /// Rewrites the [selected] strings of [strings] with [fix].
  ///
  /// Throws an [Exception] with [StringReview.localizationBlocker] when a
  /// localizing fix cannot run.
  Future<QuickFixOutcome> apply(
    StringReview strings,
    StringFix fix,
    List<HardcodedString> selected,
  ) async {
    final StringRewrite result = switch (fix) {
      StringFix.localizeStrings => await localizer.apply(
        _localization(strings),
        selected,
      ),
      StringFix.passLookup => await lookups.apply(
        _localization(strings),
        strings.lookups,
        selected,
      ),
      StringFix.makeConstants => await extractor.apply(
        strings.constants,
        selected,
      ),
    };
    return (summary: result.summary, changedFiles: result.changedFiles);
  }

  /// The localization plan of [strings].
  ///
  /// Throws an [Exception] saying why when the project cannot be localized.
  LocalizationPlan _localization(StringReview strings) =>
      strings.localization ?? (throw Exception(strings.localizationBlocker));
}
