import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// The string [text] at [offset] of `/p/lib/page.dart`, of [role].
HardcodedString _string(
  String text,
  int offset,
  fcheck.HardcodedStringRole role, {
  String evidence = '',
}) => HardcodedString(
  path: '/p/lib/page.dart',
  line: offset + 1,
  site: fcheck.HardcodedStringSite(
    offset: offset,
    length: text.length,
    textParts: [text],
    interpolations: const [],
    isWidgetOutput: false,
    role: role,
    roleEvidence: evidence,
  ),
);

void main() {
  final shown = _string('Save', 30, fcheck.HardcodedStringRole.presentation);
  final compared = _string('edit', 20, fcheck.HardcodedStringRole.data);
  final fragment = _string(
    'ticket photos',
    10,
    fcheck.HardcodedStringRole.fragment,
    evidence: 'photoType → l10n.onlyDeleteOwnPhotos(…)',
  );

  StringReview review({required bool canLocalize}) => StringReview(
    localization: canLocalize
        ? LocalizationPlan(
            projectPath: '/p',
            config: const L10nConfig(),
            importUri: 'package:app/l10n/app_localizations.dart',
            candidates: [shown, fragment],
            skipped: const {},
          )
        : null,
    localizationBlocker: canLocalize ? null : 'no template ARB file',
    constants: ConstantsPlan(
      className: 'DataKeys',
      constantsPath: '/p/lib/data_keys.dart',
      importUri: 'package:app/data_keys.dart',
      // Found again by the other plan: the same strings
      candidates: [
        _string('edit', 20, fcheck.HardcodedStringRole.data),
        _string('Save', 30, fcheck.HardcodedStringRole.presentation),
      ],
      rejected: {fragment: 'with interpolations'},
      skipped: const {'with interpolations': 1},
    ),
  );

  test('groups the strings of both plans by role, once each', () {
    final strings = review(canLocalize: true);

    expect(strings.withRole(fcheck.HardcodedStringRole.presentation), [shown]);
    expect(strings.withRole(fcheck.HardcodedStringRole.data), [compared]);
    expect(strings.withRole(fcheck.HardcodedStringRole.fragment), [fragment]);
    expect(strings.withRole(fcheck.HardcodedStringRole.unknown), isEmpty);
    expect(strings.candidatesOf(QuickFix.makeConstants), contains(shown));
    expect(strings.whyNot(QuickFix.localizeStrings, shown), isNull);
    expect(
      strings.whyNot(QuickFix.makeConstants, fragment),
      'skips strings with interpolations',
    );
  });

  test('says why when the project cannot be localized', () {
    final strings = review(canLocalize: false);

    expect(strings.candidatesOf(QuickFix.localizeStrings), isEmpty);
    // Still listed: rejected by the constants plan
    expect(strings.withRole(fcheck.HardcodedStringRole.fragment), [fragment]);
    expect(
      strings.whyNot(QuickFix.localizeStrings, shown),
      'cannot run: no template ARB file',
    );
  });

  test('asks the AI to fix what FIDE cannot, saying why', () {
    expect(
      review(canLocalize: true).aiRequest([fragment]),
      endsWith(
        '- "ticket photos" at page.dart:11, fragments '
        '(photoType → l10n.onlyDeleteOwnPhotos(…)): have each caller pass '
        'one whole localized message instead',
      ),
    );
  });
}
