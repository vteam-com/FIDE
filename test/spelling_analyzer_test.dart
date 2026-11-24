import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/spelling_report.dart';
import 'package:fide/services/spelling_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_spelling_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  /// Writes [content] at the project-relative [path].
  void write(String path, String content) => File(p.join(project.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  test('reports unknown words of lib and test, and scores the rest', () {
    write('lib/a.dart', 'class Widget {}\n// the adaptive landsacpe here\n');
    write('test/a_test.dart', 'void main() {}\n');

    final report = const SpellingAnalyzer().analyze(project.path);

    expect(report.findings.map((finding) => finding.word), ['landsacpe']);
    expect(report.findings.single.line, 2);
    expect(report.findings.single.suggestion, 'landscape');
    expect(report.score, lessThan(AppMetric.maxScore));
  });

  test('the allowlist accepts the words listed in .fide-words', () {
    write('lib/a.dart', '// testx and Firebase here\n');
    write(
      SpellingAnalyzer.allowlistName,
      '# project words\ntestx\n\nfirebase\n',
    );

    final report = const SpellingAnalyzer().analyze(project.path);

    expect(report.findings, isEmpty);
  });

  test('generated localizations are not checked, as they are not English', () {
    write('lib/l10n/generated/app_localizations_fr.dart', '// votre supprim\n');

    final report = const SpellingAnalyzer().analyze(project.path);

    expect(report.findings, isEmpty);
    expect(report.wordsChecked, 0);
  });

  test('a project with no words scores the maximum', () {
    const report = SpellingReport(
      rootPath: '/p',
      wordsChecked: 0,
      distinctWords: 0,
      findings: [],
    );

    expect(report.score, AppMetric.maxScore);
  });
}
