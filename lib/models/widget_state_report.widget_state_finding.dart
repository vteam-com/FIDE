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

  /// The 1-based line the `State` is declared on, or a test reaches into
  /// it on.
  final int line;

  /// Absolute path of the file declaring the `State`, or of the test
  /// reaching into it.
  final String path;

  /// How the `State` strays.
  final WidgetStateProblem problem;

  /// The `State` class's name.
  final String state;

  /// The widget the `State` belongs to.
  final String widget;

  /// Absolute path of the file declaring [widget].
  final String widgetPath;

  /// Whether it is about a test reaching into the `State`, at the test's
  /// [line] of [path], rather than about the `State` itself.
  bool get isInTest => problem == WidgetStateProblem.reachedByTest;

  /// Whether Fix States fixes it, moving, renaming or marking the `State`
  /// in its widget's library: not one in another library than its widget,
  /// nor a test reaching into it, which the AI rewrites.
  bool get isFixableByCode => isInWidgetLibrary && !isInTest;

  /// What is wrong and what to do, in one line.
  String get message => switch (problem) {
    WidgetStateProblem.apart =>
      '$state belongs beside $widget, in ${p.basename(widgetPath)}',
    WidgetStateProblem.public =>
      'No other file uses $state: make it private, _$state',
    WidgetStateProblem.reachedByTest =>
      'Tests $state, private to $widget: test $widget itself',
  };
}
