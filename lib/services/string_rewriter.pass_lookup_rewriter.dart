part of 'string_rewriter.dart';

/// Runs [StringFix.passLookup]: localizes strings through the widget
/// fields they are passed to, planning from the localization plan.
class PassLookupRewriter implements StringRewriter {
  /// Creates the rewriter passing lookups through [_passer].
  const PassLookupRewriter(this._passer);

  final StringLookupPasser _passer;

  @override
  Future<StringReview> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
    StringReview review,
  ) async {
    final localization = review.localization;
    if (localization == null) return review;
    return review.copyWith(lookups: await _passer.plan(localization));
  }

  @override
  Future<StringRewrite> apply(
    StringReview review,
    List<HardcodedString> selected,
  ) async => _passer.apply(_localizationOf(review), review.lookups, selected);
}
