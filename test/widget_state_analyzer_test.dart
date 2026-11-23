import 'dart:io';

import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/widget_state_issues.dart';
import 'package:fide/models/widget_state_report.dart';
import 'package:fide/services/widget_state_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A stateful widget, `Counter`, whose State is named [state], extending
/// [base].
String _widget(String state, {String base = 'StatefulWidget'}) =>
    '''
class Counter extends $base {
  const Counter();

  @override
  State<Counter> createState() => $state();
}
''';

/// The State of [_widget], named [state], extending [base].
String _state(String state, {String base = 'State'}) =>
    '''
class $state extends $base<Counter> {
  int count = 0;
}
''';

void main() {
  late String project;

  setUp(() {
    project = Directory.systemTemp
        .createTempSync('fide_widget_state_')
        .resolveSymbolicLinksSync();
  });
  tearDown(() => Directory(project).deleteSync(recursive: true));

  void write(String path, String content) {
    File(p.join(project, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// The findings, as (file, problem) pairs.
  List<(String, WidgetStateProblem)> findings() => [
    for (final finding in const WidgetStateAnalyzer().analyze(project).findings)
      (p.relative(finding.path, from: project), finding.problem),
  ];

  test('a private State beside its widget is in place', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );

    final report = const WidgetStateAnalyzer().analyze(project);

    expect(report.findings, isEmpty);
    expect(report.stateCount, 1);
  });

  test('a public State no other file names is to make private', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    expect(findings(), [('lib/counter.dart', WidgetStateProblem.public)]);
  });

  test('a State in a part file is apart from its widget; the test reaching '
      'into it is wrong', () {
    write(
      'lib/counter.dart',
      "part 'counter_state.dart';\n\n${_widget('CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "part of 'counter.dart';\n\n${_state('CounterState')}",
    );
    write(
      'test/counter_test.dart',
      'int countOf(Object state) => (state as CounterState).count;\n',
    );

    final report = const WidgetStateAnalyzer().analyze(project);

    expect(
      [for (final finding in report.findings) finding.message],
      [
        'CounterState belongs beside Counter, in counter.dart',
        'Tests CounterState, private to Counter: test Counter itself',
      ],
    );
    expect(report.findings.first.isInWidgetLibrary, isTrue);
  });

  test('a State another library of the app reaches by name stays public', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );
    write(
      'lib/panel.dart',
      "import 'counter.dart';\n\nfinal key = GlobalKey<CounterState>();\n",
    );

    expect(findings(), isEmpty);
  });

  test('a State in a library of its own is apart, out of the widget\'s '
      'library', () {
    write(
      'lib/counter.dart',
      "import 'counter_state.dart';\n\n${_widget('CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "import 'counter.dart';\n\n${_state('CounterState')}",
    );

    final finding = const WidgetStateAnalyzer()
        .analyze(project)
        .findings
        .singleWhere((finding) => finding.problem == WidgetStateProblem.apart);

    expect(finding.isInWidgetLibrary, isFalse);
  });

  test('knows Riverpod\'s stateful widgets and States', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState', base: 'ConsumerStatefulWidget')}\n'
          '${_state('CounterState', base: 'ConsumerState')}',
    );

    expect(findings(), [('lib/counter.dart', WidgetStateProblem.public)]);
  });

  test('leaves a State whose line, or file, its ignore comment ends, a '
      'doc comment above it or not', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n/// Counts.\n'
          '${_state('CounterState').replaceFirst('{', '{ // ignore: fcheck_widget_state')}',
    );
    write(
      'lib/counter_state.dart',
      "// ignore: fcheck_widget_state\nimport 'counter.dart';\n\n"
          '${_state('OtherState')}',
    );

    expect(findings(), isEmpty);
  });

  test('the issue lists each State, fixed by Fix States, not the AI', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    final issue = const WidgetStateAnalyzer()
        .analyze(project)
        .issues(project)
        .single;

    expect(issue.label, 'Widget States: -1% (1 issue)');
    expect(issue.findings.single.text, startsWith('No other file uses'));
    expect(issue.quickFixes, [QuickFix.fixStates]);
    // Fix States makes it private: nothing for the AI
    expect(issue.aiActionLabel, isNull);
    expect(issue.guidance, contains('// ignore: fcheck_widget_state'));
  });

  test('a State only tests use is the tests\' fault, flagged as errors at '
      'their lines, one a line, which Fix States removes', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n@visibleForTesting\n${_state('CounterState')}',
    );
    write('test/counter_test.dart', '''
void check(Tester tester) {
  final CounterState state = tester.state<CounterState>(finder);
  print(state.count);
  final other = tester.state<CounterState>(finder); // ignore: fcheck_widget_state
}
''');

    final tests = const WidgetStateAnalyzer()
        .analyze(project)
        .issues(project)
        .single;

    expect(tests.label, 'Tests reaching into States: -2% (1 test line)');
    expect(tests.tone, StatusTone.error);
    expect(
      tests.findings.single.text,
      'Tests CounterState, private to Counter: test Counter itself',
    );
    expect(tests.findings.single.line, 2);
    // Fix States removes them, in the same click as the State
    expect(tests.quickFixes, [QuickFix.fixStates]);
    expect(tests.aiActionLabel, isNull);
    expect(tests.guidance, contains('is wrong'));
  });

  test('a test naming a private State, which can\'t compile, reaches into '
      'it too', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );
    write('test/counter_test.dart', '_CounterState? state;\n');

    expect(findings(), [
      ('test/counter_test.dart', WidgetStateProblem.reachedByTest),
    ]);
  });

  test('a test calling the widget\'s createState reaches into its State, '
      'whatever holds it', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );
    write('test/counter_test.dart', '''
void main() {
  late dynamic state;
  const counter = Counter();
  state = counter.createState();
  final other = Counter().createState();
}
''');

    expect(
      [
        for (final finding
            in const WidgetStateAnalyzer().analyze(project).findings)
          (finding.line, finding.message),
      ],
      [
        (4, 'Tests _CounterState, private to Counter: test Counter itself'),
        (5, 'Tests _CounterState, private to Counter: test Counter itself'),
      ],
    );
  });
}
