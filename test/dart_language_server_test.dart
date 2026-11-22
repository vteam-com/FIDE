import 'dart:io';

import 'package:fide/panels/center/editor/editor_diagnostics.dart';
import 'package:fide/panels/center/editor/editor_session.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fake_code_formatter.dart';
import 'fake_file_content_reader.dart';

/// Longest the real server may take to analyze the small test project.
const Duration _analysisTimeout = Duration(seconds: 60);

/// How often [_until] checks its condition.
const Duration _pollInterval = Duration(milliseconds: 50);

/// Waits until [condition] holds, failing after [_analysisTimeout].
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(_analysisTimeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting');
    await Future<void>.delayed(_pollInterval);
  }
}

/// The real `dart language-server`, driven through the editor's session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late DartLanguageServer server;
  late String mainPath;
  late String otherPath;

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp('fide_lsp_');
    project = Directory(temp.resolveSymbolicLinksSync());
    mainPath = p.join(project.path, 'lib', 'main.dart');
    otherPath = p.join(project.path, 'lib', 'other.dart');
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: probe\nenvironment:\n  sdk: ^3.0.0\n');
    File(mainPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('int count = 1;\n');
    File(otherPath).writeAsStringSync('String other = 1;\n');
    server = await DartLanguageServer.start(
      dart: FlutterSdk.dartExecutable,
      projectPath: project.path,
    );
  });

  tearDownAll(() {
    server.dispose();
    project.deleteSync(recursive: true);
  });

  test('checks and completes the text as typed, and only that file', () async {
    final documents = OpenDocumentsNotifier(
      reader: FakeFileContentReader()..files[mainPath] = 'int count = 1;\n',
    );
    await documents.open(mainPath);
    final session = EditorSession(
      documents: documents,
      formatter: const FakeCodeFormatter(),
      git: GitService(const ProcessRunner()),
      languageServer: server,
    )..load(documents.state.active!);
    final diagnostics = EditorDiagnostics(
      session.code,
      server: server.diagnostics,
    )..show(mainPath, null);
    addTearDown(() {
      diagnostics.dispose();
      session.dispose();
    });

    // Unsaved: the file on disk has no error
    session.code.text =
        "int count = 'unsaved';\nint typedOnly = 2;\nint use() => typedOnly;\n";

    await _until(
      () =>
          server.diagnostics.of(otherPath).isNotEmpty &&
          session.code.diagnostics.isNotEmpty,
    );
    expect(
      session.code.diagnostics.single.message,
      contains("'String' can't be assigned to a variable of type 'int'"),
    );
    expect(session.code.diagnostics.single.range['start'], {
      'line': 0,
      'character': 12,
    });

    final completions = await server.config.getCompletions(
      mainPath,
      2,
      'int use() => '.length,
    );
    expect(completions.map((c) => c.label), contains('typedOnly'));
  });
}
