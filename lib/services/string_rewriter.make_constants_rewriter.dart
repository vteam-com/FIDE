part of 'string_rewriter.dart';

/// Runs [StringFix.makeConstants]: makes data-id strings constants.
class MakeConstantsRewriter implements StringRewriter {
  /// Creates the rewriter extracting constants through [_extractor].
  const MakeConstantsRewriter(this._extractor);

  final StringConstantsExtractor _extractor;

  @override
  Future<StringReview> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
    StringReview review,
  ) async =>
      review.copyWith(constants: await _extractor.plan(projectPath, metrics));

  @override
  Future<StringRewrite> apply(
    StringReview review,
    List<HardcodedString> selected,
  ) => _extractor.apply(review.constants, selected);
}
