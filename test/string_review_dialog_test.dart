import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/widgets/check_list_tile.dart';
import 'package:fide/widgets/string_review_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// How many strings users read the review holds.
const int _shownCount = 600;

/// The string [text] at [offset] of `/p/lib/page.dart`, of [role].
HardcodedString _string(
  String text,
  int offset,
  fcheck.HardcodedStringRole role,
) => HardcodedString(
  path: '/p/lib/page.dart',
  line: offset + 1,
  site: fcheck.HardcodedStringSite(
    offset: offset,
    length: text.length,
    textParts: [text],
    interpolations: const [],
    isWidgetOutput: false,
    role: role,
    roleEvidence: '',
  ),
);

/// A review counting how often the fixes' candidates are gathered.
class _CountingReview extends StringReview {
  _CountingReview({required super.localization, required super.constants})
    : super(localizationBlocker: null);

  /// How many times [candidatesOf] ran.
  int candidateCalls = 0;

  @override
  List<HardcodedString> candidatesOf(StringFix fix) {
    candidateCalls++;
    return super.candidatesOf(fix);
  }
}

void main() {
  final shown = [
    for (var i = 0; i < _shownCount; i++)
      _string('Text $i', i, fcheck.HardcodedStringRole.presentation),
  ];
  final compared = _string(
    'edit',
    _shownCount,
    fcheck.HardcodedStringRole.data,
  );

  _CountingReview review() => _CountingReview(
    localization: LocalizationPlan(
      projectPath: '/p',
      config: const L10nConfig(),
      importUri: 'package:app/l10n/app_localizations.dart',
      candidates: shown,
      skipped: const {},
    ),
    constants: ConstantsPlan(
      className: 'DataKeys',
      constantsPath: '/p/lib/data_keys.dart',
      importUri: 'package:app/data_keys.dart',
      candidates: [compared],
      skipped: const {},
    ),
  );

  testWidgets('checking a string neither judges the strings again nor '
      'builds the rows out of view', (tester) async {
    final strings = review();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 600,
              child: StringReviewDialog(review: strings, onOpen: (_) {}),
            ),
          ),
        ),
      ),
    );
    final localize = StringFix.localizeStrings.label;
    expect(find.text('$localize ($_shownCount)'), findsNothing);
    expect(find.byType(CheckListTile).evaluate().length, lessThan(_shownCount));
    final calls = strings.candidateCalls;

    await tester.tap(find.text('"Text 0"'));
    await tester.pump();
    await tester.tap(find.text('"Text 1"'));
    await tester.pump();

    expect(strings.candidateCalls, calls);
    expect(
      tester.widget<CheckListTile>(find.byType(CheckListTile).first).value,
      isFalse,
    );

    // The group's actions, built once scrolled to, count the checked ones
    await tester.scrollUntilVisible(
      find.textContaining(localize),
      3000,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('$localize (${_shownCount - 2})'), findsOneWidget);
    expect(strings.candidateCalls, calls);
  });
}
