import 'package:code_forge/code_forge.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/editor/editor_diagnostics.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const project = '/project';
  const path = '$project/lib/main.dart';
  const other = '$project/lib/other.dart';
  const text = 'void main() {\n  final x = 42;\n}';

  const magicNumbers = QualityIssue(
    label: 'Magic numbers: -2% (2 issues)',
    title: 'Magic numbers',
    findings: [
      QualityFinding(path: path, line: 2, text: '42'),
      QualityFinding(path: other, line: 1, text: '7'),
      QualityFinding(path: path, line: 99, text: '3'),
    ],
  );

  const secrets = QualityIssue(
    label: 'Secrets: -5% (1 issues)',
    title: 'Secrets',
    tone: StatusTone.error,
    findings: [QualityFinding(path: path, line: 2, text: 'api key')],
  );

  const dartAnalyzer = QualityIssue(
    label: 'Dart analyzer: -1% (1 warning)',
    title: DartAnalysis.title,
    tone: StatusTone.warning,
    findings: [QualityFinding(path: path, line: 2, text: 'unused x')],
  );

  /// The `publishDiagnostics` params of one error on 0-based [line] of
  /// [file], from [start] to [end].
  Map<String, dynamic> published(
    String file, {
    int line = 1,
    int start = 8,
    int end = 9,
    String message = 'Undefined name',
  }) => {
    'uri': Uri.file(file).toString(),
    'diagnostics': [
      {
        'severity': 1,
        'message': message,
        'range': {
          'start': {'line': line, 'character': start},
          'end': {'line': line, 'character': end},
        },
      },
    ],
  };

  late CodeForgeController controller;

  setUp(() => controller = CodeForgeController()..text = text);

  test('underlines the file findings from indentation to line end', () {
    EditorDiagnostics(controller).show(path, const [magicNumbers]);

    expect(controller.diagnostics, hasLength(1));
    final diagnostic = controller.diagnostics.single;
    expect(diagnostic.severity, 2);
    expect(diagnostic.message, 'Magic numbers: 42');
    expect(diagnostic.range['start'], {'line': 1, 'character': 2});
    expect(diagnostic.range['end'], {'line': 1, 'character': 15});
  });

  test('gives the diagnostics of a line, most severe first', () {
    final diagnostics = EditorDiagnostics(controller)
      ..show(path, const [magicNumbers, secrets]);

    expect(diagnostics.onLine(0), isNull);
    expect(diagnostics.onLine(1), (
      tone: StatusTone.error,
      message: 'Secrets: api key · Magic numbers: 42',
    ));
  });

  test('clears the findings without issues', () {
    EditorDiagnostics(controller)
      ..show(path, const [magicNumbers])
      ..show(path, null);

    expect(controller.diagnostics, isEmpty);
  });

  group('with a language server', () {
    late ServerDiagnostics server;

    setUp(() => server = ServerDiagnostics(project));

    test('shows its diagnostics of the file, then the findings', () {
      server.publish(published(path));
      EditorDiagnostics(
        controller,
        server: server,
      ).show(path, const [magicNumbers]);

      expect(controller.diagnostics.map((d) => d.message), [
        'Undefined name',
        'Magic numbers: 42',
      ]);
      expect(controller.diagnostics.first.range['start'], {
        'line': 1,
        'character': 8,
      });
    });

    test("leaves out dart analyze's findings, which it reports newer", () {
      EditorDiagnostics(
        controller,
        server: server,
      ).show(path, const [dartAnalyzer, magicNumbers]);

      expect(controller.diagnostics.map((d) => d.message), [
        'Magic numbers: 42',
      ]);
    });

    test("keeps dart analyze's findings in a file it doesn't analyze", () {
      const yaml = '$project/pubspec.yaml';
      const yamlIssue = QualityIssue(
        label: 'Dart analyzer: -1% (1 warning)',
        title: DartAnalysis.title,
        findings: [QualityFinding(path: yaml, line: 1, text: 'bad key')],
      );
      EditorDiagnostics(
        controller,
        server: server,
      ).show(yaml, const [yamlIssue]);

      expect(controller.diagnostics, hasLength(1));
    });

    test('follows the diagnostics it publishes for the file', () {
      EditorDiagnostics(controller, server: server).show(path, null);

      server.publish(published(path));
      expect(controller.diagnostics, hasLength(1));

      server.publish({'uri': Uri.file(path).toString(), 'diagnostics': []});
      expect(controller.diagnostics, isEmpty);
    });

    test("puts the file's back when the editor shows another file's", () {
      server.publish(published(path));
      EditorDiagnostics(controller, server: server).show(path, null);

      // CodeForge shows whatever file the server reports on
      server.publish(published(other, message: 'Elsewhere'));
      controller.diagnosticsNotifier.value = server.of(other);

      expect(controller.diagnostics.single.message, 'Undefined name');
    });

    test('stops following the editor and the server once disposed', () {
      EditorDiagnostics(controller, server: server)
        ..show(path, null)
        ..dispose();

      server.publish(published(path));
      expect(controller.diagnostics, isEmpty);
    });
  });
}
