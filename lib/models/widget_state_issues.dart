import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/widget_state_report.dart';

/// The widget State check's report as the project's quality shows it: one
/// issue listing every `State` out of place, and the quality-score points
/// they cost.
extension WidgetStateIssues on WidgetStateReport {
  /// The kind of problem the issue names.
  static const String title = 'Widget States';

  /// Flutter's convention for a stateful widget's two classes, as
  /// Markdown, for the user and the AI.
  static const String _guidance =
      'A stateful widget is two classes: the widget, and the `State` its '
      '`createState()` makes. The `State` is part of its widget, not a '
      'class of its own:\n\n'
      '- it lives beside its widget, in the widget\'s file, not in a part '
      'file or a file of its own;\n'
      '- it is private (`_FooState`), as only its widget makes it; it stays '
      'public only when other files reach it by name, through a '
      '`GlobalKey<FooState>` or a test\'s `tester.state<FooState>(…)`.\n\n'
      '**Fix States** moves each `State` beside its widget and makes it '
      'private when no other file names it. Start a file with '
      '`// ignore: fcheck_widget_state`, or end a `State`\'s line with it, '
      'to leave it as it is.';

  /// Quality-score points the findings cost, capped.
  int get deduction => QualityIssue.deductionOf(
    findings.length,
    points: AppMetric.widgetStatePoints,
    max: AppMetric.widgetStatePointsMax,
  );

  /// The issue listing every finding, located under the project folder
  /// [rootPath]; null when there is none.
  QualityIssue? issue(String rootPath) => findings.isEmpty
      ? null
      : QualityIssue(
          label: QualityIssue.deductionLabel(
            title,
            deduction,
            findings.length.count('issue'),
          ),
          title: title,
          guidance: _guidance,
          rootPath: rootPath,
          findings: [
            for (final finding in findings)
              QualityFinding(
                path: finding.path,
                line: finding.line,
                text: finding.message,
              ),
          ],
          quickFixes: const [QuickFix.fixStates],
          // Fix States moves and renames them: nothing left for the AI
          aiVerb: null,
        );
}
