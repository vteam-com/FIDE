import 'dart:io';

import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

// Answers every command with [stdout] and [exitCode], or throws as if the
// executable were missing when [missing] is set
class ScriptedRunner extends ProcessRunner {
  final String stdout;
  final int exitCode;
  final bool missing;

  const ScriptedRunner({
    this.stdout = '',
    this.exitCode = 0,
    this.missing = false,
  });

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    if (missing) {
      throw ProcessException(executable, arguments, 'No such file');
    }
    return ProcessResult(0, exitCode, stdout, '');
  }
}

void main() {
  group('ProcessRunner probes', () {
    test('outputOf returns stdout only on success', () async {
      expect(
        await const ScriptedRunner(stdout: 'ok').outputOf('tool', []),
        'ok',
      );
      expect(
        await const ScriptedRunner(exitCode: 1).outputOf('tool', []),
        null,
      );
      expect(
        await const ScriptedRunner(missing: true).outputOf('tool', []),
        null,
      );
    });

    test('succeeds is false when the tool is missing', () async {
      expect(await const ScriptedRunner().succeeds('tool', []), true);
      expect(
        await const ScriptedRunner(missing: true).succeeds('tool', []),
        false,
      );
    });
  });

  test('FlutterSdk parses Flutter and Dart versions', () async {
    const output =
        'Flutter 3.24.0 • channel stable\nTools • Dart 3.5.0 • DevTools 2.37.2';

    final versions = await const FlutterSdk(ScriptedRunner(stdout: output))
        .versions();

    expect(versions?.flutter, '3.24.0');
    expect(versions?.dart, '3.5.0');
    expect(
      await const FlutterSdk(ScriptedRunner(missing: true)).versions(),
      isNull,
    );
  });

  test('GitService.version distinguishes missing from unparseable', () async {
    expect(
      await const GitService(
        ScriptedRunner(stdout: 'git version 2.39.3 (Apple Git-145)'),
      ).version(),
      '2.39.3',
    );
    expect(
      await const GitService(ScriptedRunner(stdout: 'weird')).version(),
      'Unknown',
    );
    expect(
      await const GitService(ScriptedRunner(missing: true)).version(),
      isNull,
    );
  });

  test('discardChanges never deletes files when git cannot run', () async {
    final repo = Directory.systemTemp.createTempSync('fide_discard_');
    addTearDown(() => repo.deleteSync(recursive: true));
    final file = File('${repo.path}/keep.dart')..writeAsStringSync('x');

    await expectLater(
      const GitService(ScriptedRunner(missing: true))
          .discardChanges(repo.path, ['keep.dart']),
      throwsA(isA<GitException>()),
    );
    expect(file.existsSync(), true);
  });
}
