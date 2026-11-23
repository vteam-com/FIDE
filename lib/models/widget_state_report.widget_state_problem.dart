part of 'widget_state_report.dart';

/// How a widget's `State` strays from Flutter's convention.
enum WidgetStateProblem {
  /// It is in another file than its widget, such as a part file.
  apart,

  /// It is public though no other library names it.
  public,
}
