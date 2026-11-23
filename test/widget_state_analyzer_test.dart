import 'dart:io';

import 'package:fide/models/quick_fix.dart';
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

  test('a State in a part file, which a test names, is apart from its '
      'widget, rightly public', () {
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

    expect(report.findings.single.problem, WidgetStateProblem.apart);
    expect(report.findings.single.isInWidgetLibrary, isTrue);
    expect(
      report.findings.single.message,
      'CounterState belongs beside Counter, in counter.dart',
    );
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

  test('leaves a State whose line, or file, its ignore comment ends', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n'
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

    final issue = const WidgetStateAnalyzer().analyze(project).issue(project)!;

    expect(issue.label, 'Widget States: -1% (1 issue)');
    expect(issue.findings.single.text, startsWith('No other file uses'));
    expect(issue.quickFixes, [QuickFix.fixStates]);
    expect(issue.aiActionLabel, isNull);
    expect(issue.guidance, contains('// ignore: fcheck_widget_state'));
  });
}
