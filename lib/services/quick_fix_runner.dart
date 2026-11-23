import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/string_fixer.dart';

/// Asks the user to confirm [fix], explained by [message].
typedef QuickFixConfirmation = Future<bool> Function(
  QuickFix fix,
  String message,
);

/// fCheck's analysis of the project at [projectPath] as its files are
/// now, made earlier with the same settings; null when there is none.
typedef LatestCodeMetrics = Future<fcheck.ProjectMetrics?> Function(
  String projectPath,
);

/// Runs a [QuickFix] on a project from an fCheck analysis of its current
/// files, for the issue dialogs and for the AI, which calls it through a
/// hook; each fix runs through its own [QuickFixHandler].
///
/// The dialogs pass a [QuickFixConfirmation] and review hardcoded strings
/// through [reviewStrings] and [applyStrings]; without them, a fix runs
/// unasked and rewrites only the strings of its [StringFix.role].
class QuickFixRunner {
  /// Creates a runner analyzing through [review], unless [latest] has an
  /// analysis of the current files, and running each fix with its
  /// handler in [handlers].
  const QuickFixRunner({
    required this.review,
    required this.strings,
    required this.handlers,
    this.latest,
  });

  /// The step a fix starts at, analyzing the project's current files,
  /// which the dialog blocking the app shows first.
  static const String analyzingStep = 'Analyzing the project…';

  /// Analyzes the project with fCheck.
  final CodeReview review;

  /// An analysis of the project's current files made earlier, such as the
  /// overview's, reused instead of analyzing again.
  final LatestCodeMetrics? latest;

  /// Reviews and rewrites hardcoded strings.
  final StringFixer strings;

  /// The handler of each fix.
  final Map<QuickFix, QuickFixHandler> handlers;

  /// What localizing and making constants would do to the hardcoded
  /// strings of the project at [projectPath], from an analysis of its
  /// current files.
  Future<StringReview> reviewStrings(String projectPath) async =>
      strings.review(projectPath, await _analyze(projectPath));

  /// fCheck's analysis of the project at [projectPath] as its files are
  /// now: [latest]'s when it has one, else a fresh one.
  Future<fcheck.ProjectMetrics> _analyze(String projectPath) async =>
      await latest?.call(projectPath) ?? await review.analyze(projectPath);

  /// Rewrites the [selected] strings of [review] with [fix].
  Future<QuickFixOutcome> applyStrings(
    StringReview review,
    StringFix fix,
    List<HardcodedString> selected,
  ) => strings.apply(review, fix, selected);

  /// Applies [fix] to the project at [projectPath], telling [onProgress]
  /// about long steps, its model requests stopped by [cancel]; null when
  /// the user cancels through [confirm].
  ///
  /// Throws a [StateError] when [fix] has no handler.
  Future<QuickFixOutcome?> run(
    String projectPath,
    QuickFix fix, {
    QuickFixConfirmation? confirm,
    void Function(String)? onProgress,
    AiCancelToken? cancel,
  }) async {
    final handler = handlers[fix];
    if (handler == null) throw StateError('${fix.label} has no handler');
    return handler.run(
      QuickFixRequest(
        projectPath: projectPath,
        metrics: await _analyze(projectPath),
        confirm: (message) async => await confirm?.call(fix, message) ?? true,
        onProgress: onProgress,
        cancel: cancel,
      ),
    );
  }
}
