import 'dart:async';
import 'dart:io';

import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every command with [exitCode] and `oops` on stderr.
class _ExitRunner extends ProcessRunner {
  const _ExitRunner(this.exitCode);

  final int exitCode;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async => ProcessResult(0, exitCode, 'out', 'oops');
}

void main() {
  test('runChecked returns the result of the expected exit code', () async {
    final result = await const _ExitRunner(1)
        .runChecked('git', ['diff'], expectedExitCode: 1);

    expect(result.stdout, 'out');
  });

  test('runChecked throws the command and its stderr by default', () {
    expect(
      const _ExitRunner(1).runChecked('flutter', ['gen-l10n']),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          contains('flutter gen-l10n failed: oops'),
        ),
      ),
    );
  });

  test('runChecked throws what the error builder makes', () {
    expect(
      const _ExitRunner(2).runChecked('pod', [
        'deintegrate',
      ], error: (result) => StateError('exit ${result.exitCode}')),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'exit 2')),
    );
  });

  test(
    'runUntil closes stdin, so a command reading it ends',
    () async {
      final result = await const ProcessRunner().runUntil(
        'cat',
        const [],
        stop: Completer<void>().future,
      );

      expect(result.exitCode, 0);
      expect(result.stdout, isEmpty);
    },
    skip: Platform.isWindows ? 'cat is not on Windows' : null,
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
