part of 'string_rewriter.dart';

/// Runs [StringFix.localizeStrings]: moves strings to the template ARB
/// file and replaces them with lookups.
class LocalizeStringsRewriter implements StringRewriter {
  /// Creates the rewriter localizing through [_localizer].
  const LocalizeStringsRewriter(this._localizer);

  final StringLocalizer _localizer;

  @override
  Future<StringReview> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
    StringReview review,
  ) async {
    try {
      return review.copyWith(
        localization: await _localizer.plan(projectPath, metrics),
      );
    } on Exception catch (e) {
      return review.copyWith(
        localizationBlocker: '$e'.replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Future<StringRewrite> apply(
    StringReview review,
    List<HardcodedString> selected,
  ) async => _localizer.apply(_localizationOf(review), selected);
}
