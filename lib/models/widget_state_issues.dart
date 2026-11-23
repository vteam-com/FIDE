import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/widget_state_report.dart';

/// The widget State check's report as the project's quality shows it: an
/// issue listing every `State` out of place, which Fix States fixes, and
/// one listing, as errors, every test line reaching into a `State`,
/// explaining how to check the widget instead; and the quality-score
/// points they cost.
extension WidgetStateIssues on WidgetStateReport {
  /// The kind of problem the `State`s' issue names.
  static const String title = 'Widget States';

  /// The kind of problem the tests' issue names.
  static const String testsTitle = 'Tests reaching into States';

  /// Flutter's convention for a stateful widget's two classes, as
  /// Markdown, for the user and the AI.
  static const String _guidance =
      'A stateful widget is two classes: the widget, and the `State` its '
      '`createState()` makes. The `State` is part of its widget, not a '
      'class of its own:\n\n'
      '- it lives beside its widget, in the widget\'s file, not in a part '
      'file or a file of its own;\n'
      '- it is private (`_FooState`), as only its widget makes it; it stays '
      'public only when other files of the app reach it by name, through a '
      '`GlobalKey<FooState>`, as Flutter\'s `FormState` is; never for a '
      'test, which checks the widget itself (see $testsTitle).\n\n'
      '**Fix States** moves each `State` beside its widget and makes it '
      'private when no other file names it. Start a file with '
      '`// ignore: fcheck_widget_state`, or end a `State`\'s line with it, '
      'to leave it as it is.';

  /// Why a test reaching into a widget's `State` is wrong, and how to
  /// check the widget instead, as Markdown, for the developer rewriting
  /// the tests.
  static const String _testsGuidance =
      'A widget\'s `State` is private to its widget: nothing outside it, a '
      'test least of all, is meant to reach into it. A test doing so, '
      '`tester.state<FooState>(…)`, is wrong: it checks how the widget '
      'works instead of what it does, breaks whenever the `State` changes '
      'though the widget still works, passes though the widget is broken, '
      'and keeps the `State` public only for itself.\n\n'
      'A widget test checks what the widget does, as its users see it:\n\n'
      '- what it shows: `find.text`, `find.byType`, `find.byKey`, and the '
      'widgets it builds, such as `tester.widget<CustomPaint>(…).painter`;\n'
      '- what it calls: the callbacks passed to it, recorded by the test '
      '(`onChanged: (value) => changed = value`);\n'
      '- acting as a user does: `tester.tap`, `tester.drag`, '
      '`tester.enterText`, then `tester.pump()`.\n\n'
      'Keep every check: each `expect` on the `State` becomes an `expect` '
      'of the same fact through the widget, not a bare `findsOneWidget`. '
      'A fact the widget never shows, such as a private field, is no fact '
      'of the widget: drop the check, or have the widget show it. Once no '
      'test reaches into a `State`, Fix States makes it private.';

  /// The findings about the `State`s themselves.
  List<WidgetStateFinding> get _stateFindings => [
    for (final finding in findings)
      if (!finding.isInTest) finding,
  ];

  /// The findings about tests reaching into a `State`.
  List<WidgetStateFinding> get _testFindings => [
    for (final finding in findings)
      if (finding.isInTest) finding,
  ];

  /// Quality-score points the findings cost, each issue's capped.
  int get deduction =>
      _deductionOf(_stateFindings) + _testsDeductionOf(_testFindings);

  /// The issues of the `State`s and of the tests reaching into them,
  /// located under the project folder [rootPath], each when it has
  /// findings.
  List<QualityIssue> issues(String rootPath) => [
    if (_stateFindings case final states when states.isNotEmpty)
      QualityIssue(
        label: QualityIssue.deductionLabel(
          title,
          _deductionOf(states),
          states.length.count('issue'),
        ),
        title: title,
        guidance: _guidance,
        rootPath: rootPath,
        findings: _qualityFindings(states),
        quickFixes: [if (isFixableByCode) QuickFix.fixStates],
        // Fix States moves, renames and marks them: nothing for the AI
        aiVerb: null,
      ),
    if (_testFindings case final tests when tests.isNotEmpty)
      QualityIssue(
        label: QualityIssue.deductionLabel(
          testsTitle,
          _testsDeductionOf(tests),
          tests.length.count('test line'),
        ),
        title: testsTitle,
        tone: StatusTone.error,
        guidance: _testsGuidance,
        rootPath: rootPath,
        findings: _qualityFindings(tests),
        // No fix: code can't tell what a test should check instead, and
        // the local model, asked to, swapped each check for a bare
        // `findsOneWidget`, passing tests that check nothing
        aiVerb: null,
      ),
  ];

  /// Quality-score points [findings] cost, capped.
  static int _deductionOf(List<WidgetStateFinding> findings) =>
      QualityIssue.deductionOf(
        findings.length,
        points: AppMetric.widgetStatePoints,
        max: AppMetric.widgetStatePointsMax,
      );

  /// Quality-score points [findings], tests reaching into a `State`, an
  /// error, cost, capped.
  static int _testsDeductionOf(List<WidgetStateFinding> findings) =>
      QualityIssue.deductionOf(
        findings.length,
        points: AppMetric.stateTestPoints,
        max: AppMetric.stateTestPointsMax,
      );

  /// [findings] as the issues list them.
  static List<QualityFinding> _qualityFindings(
    List<WidgetStateFinding> findings,
  ) => [
    for (final finding in findings)
      QualityFinding(
        path: finding.path,
        line: finding.line,
        text: finding.message,
      ),
  ];
}
