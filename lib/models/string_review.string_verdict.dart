part of 'string_review.dart';

/// What the fixes offered for one hardcoded string's role make of it,
/// worked out once for a review: why each cannot rewrite it, if it can't.
class StringVerdict {
  /// Creates the verdict of [whyNot], why each fix offered cannot rewrite
  /// the string, null for those that can.
  const StringVerdict(this.whyNot);

  /// Why each fix offered for the string's role cannot rewrite it, null
  /// for those that can, in [StringReview.fixesFor]'s order.
  final Map<StringFix, String?> whyNot;

  /// Whether a fix offered can rewrite the string; the AI fixes the
  /// others.
  bool get isFixable => whyNot.values.any((reason) => reason == null);

  /// Why each fix offered cannot rewrite the string, such as "Make
  /// Constants skips strings with interpolations".
  List<String> get reasons => [
    for (final MapEntry(key: fix, value: reason) in whyNot.entries)
      if (reason != null) '${fix.label} $reason',
  ];

  /// Whether [fix] can rewrite the string.
  bool canTake(StringFix fix) => whyNot.containsKey(fix) && whyNot[fix] == null;
}
