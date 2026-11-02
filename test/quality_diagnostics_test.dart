import 'package:code_forge/code_forge.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/editor/quality_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = '/project/lib/main.dart';

  const magicNumbers = QualityIssue(
    label: 'Magic numbers: -2% (2 issues)',
    title: 'Magic numbers',
    findings: [
      QualityFinding(path: path, line: 2, text: '42'),
      QualityFinding(path: '/project/lib/other.dart', line: 1, text: '7'),
      QualityFinding(path: path, line: 99, text: '3'),
    ],
  );

  const secrets = QualityIssue(
    label: 'Secrets: -5% (1 issues)',
    title: 'Secrets',
    tone: StatusTone.error,
    findings: [QualityFinding(path: path, line: 2, text: 'api key')],
  );

  CodeForgeController controllerWith(String text) =>
      CodeForgeController()..text = text;

  test('underlines the file findings from indentation to line end', () {
    final controller = controllerWith('void main() {\n  final x = 42;\n}')
      ..showFindings(const [magicNumbers], path);

    expect(controller.diagnostics, hasLength(1));
    final diagnostic = controller.diagnostics.single;
    expect(diagnostic.severity, 2);
    expect(diagnostic.message, 'Magic numbers: 42');
    expect(diagnostic.range['start'], {'line': 1, 'character': 2});
    expect(diagnostic.range['end'], {'line': 1, 'character': 15});
  });

  test('gives the findings of a line, most severe first', () {
    final controller = controllerWith('void main() {\n  final x = 42;\n}')
      ..showFindings(const [magicNumbers, secrets], path);

    expect(controller.findingsAt(0), isNull);
    expect(controller.findingsAt(1), (
      tone: StatusTone.error,
      message: 'Secrets: api key · Magic numbers: 42',
    ));
  });

  test('clears the findings without issues', () {
    final controller = controllerWith('void main() {\n  final x = 42;\n}')
      ..showFindings(const [magicNumbers], path)
      ..showFindings(null, path);

    expect(controller.diagnostics, isEmpty);
  });
}
