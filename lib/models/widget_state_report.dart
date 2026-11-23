import 'package:path/path.dart' as p;

part 'widget_state_report.widget_state_finding.dart';
part 'widget_state_report.widget_state_problem.dart';

/// What the widget State check found in a project: each stateful widget's
/// `State` not where Flutter's convention puts it, beside its widget, in
/// the widget's file, private (`_FooState`) unless other libraries of the
/// app reach it by name; and each test wrongly reaching into one.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class WidgetStateReport {
  /// Creates the report of [findings] among [stateCount] `State`s.
  const WidgetStateReport({required this.findings, required this.stateCount});

  /// Each `State` out of place, by file then line.
  final List<WidgetStateFinding> findings;

  /// Whether Fix States has some `State` to fix.
  bool get isFixableByCode =>
      findings.any((finding) => finding.isFixableByCode);

  /// How many widget `State`s the project's `lib` declares.
  final int stateCount;
}
