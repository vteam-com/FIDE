part of 'widget_state_report.dart';

/// How a widget's `State` strays from Flutter's convention.
enum WidgetStateProblem {
  /// It is in another file than its widget, such as a part file.
  apart,

  /// It is public though no other library names it.
  public,

  /// A test reaches into it, which is wrong: the `State` is private to
  /// its widget, and the test checks how the widget works rather than
  /// what it does; the finding is at that test's line.
  reachedByTest,
}
