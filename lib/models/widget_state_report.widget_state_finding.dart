part of 'widget_state_report.dart';

/// A widget's `State`, [state], at [line] of [path], straying from
/// Flutter's convention as [problem] says.
class WidgetStateFinding {
  /// Creates the finding of [state], the `State` of [widget], declared in
  /// [widgetPath].
  const WidgetStateFinding({
    required this.problem,
    required this.path,
    required this.line,
    required this.state,
    required this.widget,
    required this.widgetPath,
    required this.isInWidgetLibrary,
  });

  /// Whether the `State` is in its widget's library, the widget's file or
  /// one of its part files, so moving it changes no import.
  final bool isInWidgetLibrary;

  /// The 1-based line the `State` is declared on.
  final int line;

  /// Absolute path of the file declaring the `State`.
  final String path;

  /// How the `State` strays.
  final WidgetStateProblem problem;

  /// The `State` class's name.
  final String state;

  /// The widget the `State` belongs to.
  final String widget;

  /// Absolute path of the file declaring [widget].
  final String widgetPath;

  /// What is wrong and what to do, in one line.
  String get message => switch (problem) {
    WidgetStateProblem.apart =>
      '$state belongs beside $widget, in ${p.basename(widgetPath)}',
    WidgetStateProblem.public =>
      'No other file uses $state: make it private, _$state',
  };
}
