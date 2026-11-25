import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:path/path.dart' as p;

/// fCheck's widget state findings as the project's quality explains them:
/// the issue listing every `State` out of place, which Fix States fixes,
/// and the one listing, as errors, every test line reaching into a
/// `State`, which Fix States removes, explaining how to check the widget
/// instead.
extension WidgetStateIssues on fcheck.WidgetStateIssue {
  /// The kind of problem the `State`s' issue names.
  static const String title = 'Widget States';

  /// The kind of problem the tests' issue names.
  static const String testsTitle = 'Tests reaching into States';

  /// Flutter's convention for a stateful widget's two classes, as
  /// Markdown, for the user and the AI.
  static const String guidance =
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

  /// Why a test reaching into a widget's `State` is wrong, how to check
  /// the widget instead, and what Fix States removes, as Markdown.
  static const String testsGuidance =
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
      'A fact the widget never shows, such as a private field, is no fact '
      'of the widget: its check goes. **Fix States** removes every '
      'statement reaching into a `State`, with what only they used, a test '
      'left empty and the imports no longer used, then makes the `State` '
      'private; write the checks the widget calls for as you see fit.';

  /// Whether it is about a test reaching into the `State`, at the test's
  /// line, rather than about the `State` itself.
  bool get isInTest => type == fcheck.WidgetStateIssueType.reachedByTest;

  /// Whether Fix States fixes it, moving or renaming the `State` in its
  /// widget's library, or removing what a test does with it: not when the
  /// `State` is in another library than its widget.
  bool get isFixableByCode => isInWidgetLibrary;

  /// What is wrong and what to do, in one line.
  String get message => switch (type) {
    fcheck.WidgetStateIssueType.apart =>
      '$state belongs beside $widget, in ${p.basename(widgetFilePath)}',
    fcheck.WidgetStateIssueType.public =>
      'No other file uses $state: make it private, _$state',
    fcheck.WidgetStateIssueType.reachedByTest =>
      'Tests $state, private to $widget: test $widget itself',
  };
}
