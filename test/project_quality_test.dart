import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/services/dart_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'project_maintenance_test.dart' show FakeRunRunner;

/// `dart analyze` reporting an error and two warnings, piped as FIDE
/// runs it, then an info as a terminal shows it.
const String _report = '''
Analyzing demo...

  error - lib/a.dart:2:23 - The operator '-' isn't defined for the type 'String'. Try defining the operator '-'. - undefined_operator
warning - lib/a.dart:1:8 - Unused import: 'dart:io'. Try removing the import directive. - unused_import
warning - lib/b.dart:9:1 - Dead code. - dead_code
   info • lib/c.dart:4:3 • Unnecessary 'this.' qualifier. • unnecessary_this

4 issues found.''';

/// The command [DartAnalyzer] runs.
const String _command = 'dart analyze';

void main() {
  group('DartAnalysis', () {
    test('lists one issue per severity, errors first', () {
      final analysis = DartAnalysis.parse(_report, rootPath: '/demo');
      final issues = analysis.issues;

      expect(analysis.output, _report);
      expect(issues.map((issue) => issue.label), [
        'Dart analyzer: -${AppMetric.dartErrorPoints}% (1 error)',
        'Dart analyzer: -${2 * AppMetric.dartWarningPoints}% (2 warnings)',
        'Dart analyzer: -${AppMetric.dartInfoPoints}% (1 info)',
      ]);
      expect(
        analysis.deduction,
        AppMetric.dartErrorPoints +
            2 * AppMetric.dartWarningPoints +
            AppMetric.dartInfoPoints,
      );
      expect(issues.first.tone, StatusTone.error);
      expect(
        issues.first.findings.single.text,
        "The operator '-' isn't defined for the type 'String'. Try defining "
        "the operator '-'. (undefined_operator)",
      );
      final warnings = issues[1];
      expect(warnings.findings.map((finding) => finding.line), [1, 9]);
      expect(warnings.findings.last.path, '/demo/lib/b.dart');
      expect(warnings.shownPath(warnings.findings.last), 'lib/b.dart');
      expect(warnings.fixRequest, contains('lib/b.dart:9: Dead code.'));
      expect(issues.last.findings.single.path, '/demo/lib/c.dart');
    });

    test('caps what each severity costs', () {
      final errors = [
        for (var line = 1; line <= AppMetric.dartErrorPointsMax; line++)
          '  error - lib/a.dart:$line:1 - Broken. - some_error',
      ].join('\n');

      expect(
        DartAnalysis.parse(errors, rootPath: '/demo').deduction,
        AppMetric.dartErrorPointsMax,
      );
    });

    test('a clean project has no issue', () {
      expect(
        DartAnalysis.parse(
          'Analyzing demo...\nNo issues found!',
          rootPath: '/demo',
        ).issues,
        isEmpty,
      );
    });
  });

  group('DartAnalyzer', () {
    test('reads the output whatever problems it found', () async {
      final runner = FakeRunRunner({
        _command: ProcessResult(0, 3, _report, ''),
      });

      final analysis = await DartAnalyzer(runner).analyze('/demo');

      expect(analysis.diagnostics, hasLength(4));
      expect(analysis.output, _report);
      expect(runner.commands, [_command]);
    });

    test('fails with what dart printed when it did not analyze', () {
      final runner = FakeRunRunner({
        _command: ProcessResult(0, 64, '', 'no SDK'),
      });

      expect(
        DartAnalyzer(runner).analyze('/demo'),
        throwsA(predicate((error) => '$error'.contains('no SDK'))),
      );
    });
  });

  group('ProjectQuality', () {
    test('a perfect score without issues needs no attention', () {
      const quality = ProjectQuality(score: AppMetric.maxScore, issues: []);

      expect(quality.needsAttention, false);
      expect(quality.summary, 'Quality ${AppMetric.maxScore}%');
    });

    test('any issue needs attention, the first one summarized', () {
      const quality = ProjectQuality(
        score: AppMetric.maxScore,
        issues: [
          QualityIssue(label: 'Dart analyzer: 1 error'),
          QualityIssue(label: 'Missing pubspec.lock'),
        ],
      );

      expect(quality.needsAttention, true);
      expect(
        quality.summary,
        'Quality ${AppMetric.maxScore}%\nDart analyzer: 1 error (+1 more)',
      );
    });

    test('a lower score needs attention', () {
      expect(
        const ProjectQuality(
          score: AppMetric.warningScoreThreshold,
          issues: [],
        ).needsAttention,
        true,
      );
    });
  });
}
