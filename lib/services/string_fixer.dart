import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/services/string_rewriter.dart';

/// Reviews a project's hardcoded strings and rewrites the ones the user
/// picks with a [StringFix], each fix running through its own
/// [StringRewriter].
class StringFixer {
  /// Creates a fixer running each fix with its rewriter in [rewriters].
  const StringFixer(this.rewriters);

  /// The rewriter of each fix; a fix without one cannot run, such as
  /// passing lookups while no project is open.
  final Map<StringFix, StringRewriter> rewriters;

  /// What each [StringFix] would do to the hardcoded strings of the
  /// project at [projectPath], analyzed as [metrics].
  Future<StringReview> review(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    var review = StringReview.empty;
    for (final fix in StringFix.values) {
      final rewriter = rewriters[fix];
      if (rewriter == null) continue;
      review = await rewriter.plan(projectPath, metrics, review);
    }
    return review;
  }

  /// Rewrites the [selected] strings of [strings] with [fix].
  ///
  /// Throws an [Exception] with [StringReview.localizationBlocker] when a
  /// localizing fix cannot run, and a [StateError] when [fix] has no
  /// rewriter.
  Future<QuickFixOutcome> apply(
    StringReview strings,
    StringFix fix,
    List<HardcodedString> selected,
  ) async {
    final rewriter = rewriters[fix];
    if (rewriter == null) throw StateError('${fix.label} has no rewriter');
    final result = await rewriter.apply(strings, selected);
    return (summary: result.summary, changedFiles: result.changedFiles);
  }
}
