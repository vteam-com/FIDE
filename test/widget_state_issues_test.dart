import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/widget_state_issues.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A stateful widget, `Counter`, whose State is named [state].
String _widget(String state) =>
    '''
class Counter extends StatefulWidget {
  const Counter();

  @override
  State<Counter> createState() => $state();
}
''';

/// The State of [_widget], named [state].
String _state(String state) =>
    '''
class $state extends State<Counter> {
  int count = 0;
}
''';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_widget_state_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, String content) {
    File(p.join(project.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// The project's quality issues fCheck's widget state check makes.
  List<QualityIssue> issues() => [
    for (final issue in AnalyzeFolder(project).analyze().qualityIssues)
      if (issue.title == WidgetStateIssues.title ||
          issue.title == WidgetStateIssues.testsTitle)
        issue,
  ];

  test('fCheck\'s States out of place are one issue, fixed by Fix States, '
      'not the AI', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    final issue = issues().single;

    expect(issue.label, startsWith('Widget States: -'));
    expect(issue.label, endsWith('(1 issue)'));
    expect(issue.tone, StatusTone.warning);
    expect(
      issue.findings.single.text,
      'No other file uses CounterState: make it private, _CounterState',
    );
    expect(
      issue.findings.single.path,
      p.join(project.path, 'lib/counter.dart'),
    );
    expect(issue.quickFixes, [QuickFix.fixStates]);
    // Fix States makes it private: nothing for the AI
    expect(issue.aiActionLabel, isNull);
    expect(issue.guidance, contains('// ignore: fcheck_widget_state'));
  });

  test('tests reaching into a State are an error issue of their own, '
      'sharing the check\'s deduction with the States', () {
    write(
      'lib/counter.dart',
      "part 'counter_state.dart';\n\n${_widget('_CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "part of 'counter.dart';\n\n${_state('_CounterState')}",
    );
    write('test/counter_test.dart', '_CounterState? state;\n');

    final [states, tests] = issues();

    expect(
      states.findings.single.text,
      '_CounterState belongs beside Counter, in counter.dart',
    );
    expect(tests.title, WidgetStateIssues.testsTitle);
    expect(tests.label, endsWith('(1 test line)'));
    expect(tests.tone, StatusTone.error);
    expect(
      tests.findings.single.text,
      'Tests _CounterState, private to Counter: test Counter itself',
    );
    // Fix States removes them, in the same click as the State
    expect(tests.quickFixes, [QuickFix.fixStates]);
    expect(tests.aiActionLabel, isNull);
    expect(tests.guidance, contains('is wrong'));
  });

  test('a State in another library than its widget is left to the user', () {
    write(
      'lib/counter.dart',
      "import 'counter_state.dart';\n\n${_widget('_CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "import 'counter.dart';\n\n${_state('_CounterState')}",
    );

    final issue = issues().single;

    expect(issue.quickFixes, isEmpty);
    expect(issue.aiActionLabel, isNull);
  });
}
