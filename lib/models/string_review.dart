import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/hardcoded_string_role.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/lookup_plan.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:path/path.dart' as p;

/// A project's hardcoded strings for the user to review by role: what
/// localizing them and making them constants would do.
class StringReview {
  /// Creates the review of [localization] and [constants]; [localization]
  /// is null when [localizationBlocker] says why the project cannot be
  /// localized yet.
  const StringReview({
    required this.localization,
    required this.localizationBlocker,
    required this.constants,
    this.lookups = const LookupPlan(),
  });

  /// What making the strings constants would do.
  final ConstantsPlan constants;

  /// What localizing the strings would do; null when the project cannot
  /// be localized yet.
  final LocalizationPlan? localization;

  /// Why the project cannot be localized yet; null when it can.
  final String? localizationBlocker;

  /// What passing lookups to widget fields would do.
  final LookupPlan lookups;

  /// The fixes offered for strings of [role]: those rewriting that role,
  /// and all of them when the role is unknown; none for fragments, which
  /// only the AI can rewrite.
  static List<QuickFix> fixesFor(fcheck.HardcodedStringRole role) => [
    for (final fix in QuickFix.values)
      if (fix.stringRole != null &&
          (fix.stringRole == role ||
              role == fcheck.HardcodedStringRole.unknown))
        fix,
  ];

  /// Strings [fix] can rewrite.
  List<HardcodedString> candidatesOf(QuickFix fix) => switch (fix) {
    QuickFix.localizeStrings => localization?.candidates ?? const [],
    QuickFix.passLookup => lookups.candidates.keys.toList(),
    QuickFix.makeConstants => constants.candidates,
    _ => const [],
  };

  /// Strings of [role], those a fix can rewrite and those it cannot, in
  /// file order.
  List<HardcodedString> withRole(fcheck.HardcodedStringRole role) =>
      {
        ...candidatesOf(QuickFix.localizeStrings),
        ...?localization?.rejected.keys,
        ...constants.candidates,
        ...constants.rejected.keys,
      }.where((string) => string.role == role).toList()..sort(
        (a, b) => a.path == b.path
            ? a.site.offset.compareTo(b.site.offset)
            : a.path.compareTo(b.path),
      );

  /// Why [fix] cannot rewrite [string], such as "skips strings without a
  /// BuildContext"; null when it can.
  String? whyNot(QuickFix fix, HardcodedString string) {
    if (candidatesOf(fix).contains(string)) return null;
    if (localizationBlocker case final blocker?
        when fix.stringRole == fcheck.HardcodedStringRole.presentation) {
      return 'cannot run: $blocker';
    }
    if (fix == QuickFix.passLookup) {
      return 'cannot: '
          '${lookups.rejected[string] ?? LookupPlan.notAsked}';
    }
    final rejected = switch (fix) {
      QuickFix.localizeStrings => localization?.rejected,
      _ => constants.rejected,
    };
    final reason = rejected?[string];
    return reason == null
        ? 'cannot: string not found'
        : 'skips strings $reason';
  }

  /// The request asking the AI to fix [strings], which FIDE's own fixes
  /// cannot rewrite: for each, where it is, its role and the use that
  /// decided it, what to do and why FIDE could not.
  String aiRequest(List<HardcodedString> strings) =>
      'Fix these hardcoded strings, which FIDE could not rewrite itself:\n'
      '${[for (final string in strings) _aiItem(string)].join('\n')}';

  /// One line of [aiRequest] for [string].
  String _aiItem(HardcodedString string) {
    final reasons = [
      for (final fix in fixesFor(string.role))
        if (whyNot(fix, string) case final reason?) '${fix.label} $reason',
    ];
    return '- "${string.message.text}" at ${p.basename(string.path)}:'
        '${string.line}, ${string.role.label.toLowerCase()}'
        '${string.evidence.isEmpty ? '' : ' (${string.evidence})'}: '
        '${string.role.aiInstruction}'
        '${reasons.isEmpty ? '' : '; ${reasons.join(', ')}'}';
  }
}
