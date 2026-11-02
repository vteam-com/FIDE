part of 'quick_fix_handler.dart';

/// Runs a [StringFix] unasked: rewrites every string of its role it can.
class StringFixHandler implements QuickFixHandler {
  /// Creates the handler of [_fix], reviewing and rewriting through
  /// [_strings].
  const StringFixHandler(this._strings, this._fix);

  final StringFixer _strings;
  final StringFix _fix;

  @override
  Future<QuickFixOutcome> run(QuickFixRequest request) async {
    final review = await _strings.review(request.projectPath, request.metrics);
    return _strings.apply(review, _fix, review.withRole(_fix.role));
  }
}
