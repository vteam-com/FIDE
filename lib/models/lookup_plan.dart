import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/lookup_field.dart';

/// What passing lookups would do: the strings without a `BuildContext`
/// that fill a widget's `String` field, which can become a lookup function,
/// and why the others cannot.
class LookupPlan {
  /// Reason for strings other fixes take or no field was looked for.
  static const String notAsked = 'only takes strings without a BuildContext';

  /// Creates the plan of [candidates] and [rejected].
  const LookupPlan({this.candidates = const {}, this.rejected = const {}});

  /// Strings that can be localized through the field they fill.
  final Map<HardcodedString, LookupField> candidates;

  /// Strings that cannot, with the reason.
  final Map<HardcodedString, String> rejected;
}
