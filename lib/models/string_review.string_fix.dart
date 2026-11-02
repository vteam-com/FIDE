part of 'string_review.dart';

/// A [QuickFix] rewriting hardcoded strings of one role, which the user
/// picks per string in the review: where its candidates and rejections
/// are in a [StringReview].
enum StringFix {
  /// [QuickFix.localizeStrings], for strings users read.
  localizeStrings(
    QuickFix.localizeStrings,
    fcheck.HardcodedStringRole.presentation,
    _localizable,
    _whyNotLocalizable,
  ),

  /// [QuickFix.passLookup], for strings users read passed to widget fields.
  passLookup(
    QuickFix.passLookup,
    fcheck.HardcodedStringRole.presentation,
    _passable,
    _whyNotPassable,
  ),

  /// [QuickFix.makeConstants], for strings the code compares or looks up.
  makeConstants(
    QuickFix.makeConstants,
    fcheck.HardcodedStringRole.data,
    _constants,
    _whyNotConstant,
  );

  const StringFix(this.quickFix, this.role, this._candidates, this._whyNot);

  /// The quick fix this is.
  final QuickFix quickFix;

  /// The role of the strings the fix rewrites unasked.
  final fcheck.HardcodedStringRole role;

  /// The strings of a review the fix can rewrite.
  final List<HardcodedString> Function(StringReview review) _candidates;

  /// Why the fix cannot rewrite a string of a review it rejected.
  final String Function(StringReview review, HardcodedString string) _whyNot;

  /// Name of the fix, on its button.
  String get label => quickFix.label;

  /// The string fix [fix] is; null when it rewrites no strings.
  static StringFix? of(QuickFix fix) =>
      values.where((stringFix) => stringFix.quickFix == fix).firstOrNull;

  /// Strings of [review] the fix can rewrite.
  List<HardcodedString> candidatesIn(StringReview review) =>
      _candidates(review);

  /// Why the fix cannot rewrite [string], one of [review]'s strings that
  /// isn't a candidate.
  String rejectionIn(StringReview review, HardcodedString string) =>
      _whyNot(review, string);

  /// The strings [StringFix.localizeStrings] can rewrite.
  static List<HardcodedString> _localizable(StringReview review) =>
      review.localization?.candidates ?? const [];

  /// The strings [StringFix.passLookup] can rewrite.
  static List<HardcodedString> _passable(StringReview review) =>
      review.lookups.candidates.keys.toList();

  /// The strings [StringFix.makeConstants] can rewrite.
  static List<HardcodedString> _constants(StringReview review) =>
      review.constants.candidates;

  /// Why [StringFix.localizeStrings] skips [string].
  static String _whyNotLocalizable(
    StringReview review,
    HardcodedString string,
  ) => _skipped(review.localization?.rejected[string]);

  /// Why [StringFix.passLookup] cannot take [string].
  static String _whyNotPassable(StringReview review, HardcodedString string) =>
      'cannot: ${review.lookups.rejected[string] ?? LookupPlan.notAsked}';

  /// Why [StringFix.makeConstants] skips [string].
  static String _whyNotConstant(StringReview review, HardcodedString string) =>
      _skipped(review.constants.rejected[string]);

  /// The rejection for a plan's [reason], null when the plan never saw
  /// the string.
  static String _skipped(String? reason) =>
      reason == null ? 'cannot: string not found' : 'skips strings $reason';
}
