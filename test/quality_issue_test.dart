import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const finding = QualityFinding(
    path: '/project/lib/models/concert.dart',
    line: 48,
    text: '"Unknown Performer"',
  );

  test('asks the AI to fix every finding with the best practice', () {
    const issue = QualityIssue(
      label: 'Hardcoded strings',
      guidance: 'Move user-facing text to the ARB files.',
      findings: [finding],
      rootPath: '/project',
    );

    final request = issue.fixRequest!;
    expect(request, contains('"Hardcoded strings"'));
    expect(request, contains('Move user-facing text to the ARB files.'));
    expect(
      request,
      contains('- lib/models/concert.dart:48: "Unknown Performer"'),
    );
  });

  test('names its AI action and request with its verb', () {
    const issue = QualityIssue(
      label: 'Hardcoded strings',
      findings: [finding],
      aiVerb: 'Localize',
    );

    expect(issue.aiActionLabel, 'Localize with AI');
    expect(issue.fixRequest, startsWith('Localize these "Hardcoded strings"'));
    expect(
      const QualityIssue(label: 'Magic numbers').aiActionLabel,
      'Fix with AI',
    );
  });

  test('has no fix request without findings', () {
    const issue = QualityIssue(label: 'Missing pubspec.lock', guidance: 'x');

    expect(issue.fixRequest, isNull);
    expect(issue.hasDetails, isTrue);
  });

  test('has no details with only a label', () {
    expect(const QualityIssue(label: 'Checks bypassed').hasDetails, isFalse);
  });

  test('describes a finding with its title, else its label', () {
    expect(
      const QualityIssue(
        label: 'Hardcoded strings: -3% (1 issues)',
        title: 'Hardcoded strings',
      ).describe(finding),
      'Hardcoded strings: "Unknown Performer"',
    );
    expect(
      const QualityIssue(label: 'Hardcoded strings').describe(finding),
      'Hardcoded strings: "Unknown Performer"',
    );
  });
}
