import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/string_constants_extractor.dart';
import 'package:fide/services/string_localizer.dart';
import 'package:fide/services/string_lookup_passer.dart';

part 'string_rewriter.localize_strings_rewriter.dart';
part 'string_rewriter.make_constants_rewriter.dart';
part 'string_rewriter.pass_lookup_rewriter.dart';

/// Plans and applies one [StringFix] on a project's hardcoded strings;
/// each fix has its own rewriter, registered by fix in the fixer's
/// provider.
abstract interface class StringRewriter {
  /// [review] with what the fix would do to the hardcoded strings of the
  /// project at [projectPath], analyzed as [metrics]; the fixes plan in
  /// [StringFix.values] order, so a fix can plan from an earlier one's
  /// plan.
  Future<StringReview> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
    StringReview review,
  );

  /// Rewrites the [selected] strings of [review].
  ///
  /// Throws an [Exception] with [StringReview.localizationBlocker] when a
  /// localizing fix cannot run.
  Future<StringRewrite> apply(
    StringReview review,
    List<HardcodedString> selected,
  );
}

/// The localization plan of [review].
///
/// Throws an [Exception] saying why when the project cannot be localized.
LocalizationPlan _localizationOf(StringReview review) =>
    review.localization ?? (throw Exception(review.localizationBlocker));
