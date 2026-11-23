import 'dart:io';

import 'package:fide/services/ollama_installer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each command line from [exitCodes] (0 when unlisted), recording
/// the command lines run; `ollama list` outputs [models].
class _ScriptedRunner extends ProcessRunner {
  final Map<String, int> exitCodes;
  final List<String> commands = [];

  _ScriptedRunner({this.exitCodes = const {}});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String> environment = const {},
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    final exitCode = exitCodes[command] ?? 0;
    return ProcessResult(0, exitCode, '', '');
  }
}

/// Tag of the model downloaded.
const String _model = 'mimo-v2.6:9b';

void main() {
  test('installs with the script on macOS and Linux, then downloads', () async {
    for (final os in ['macos', 'linux']) {
      final runner = _ScriptedRunner();
      final installer = OllamaInstaller(runner, operatingSystem: os);

      await installer.install(_model);

      expect(runner.commands, [
        'sh -c curl -fsSL https://ollama.ai/install.sh | sh',
        'ollama pull $_model',
      ]);
    }
  });

  test('asks for a manual install on Windows and unknown systems', () async {
    for (final os in ['windows', 'fuchsia']) {
      final runner = _ScriptedRunner();
      final installer = OllamaInstaller(runner, operatingSystem: os);

      await expectLater(installer.install(_model), throwsException);
      expect(runner.commands, isEmpty);
    }
  });

  test('defaults to the operating system FIDE runs on', () {
    expect(
      OllamaInstaller(_ScriptedRunner()).operatingSystem,
      Platform.operatingSystem,
    );
  });

  test('finds Ollama installed and running, and pulls the model', () async {
    final runner = _ScriptedRunner();
    final installer = OllamaInstaller(runner, operatingSystem: 'linux');

    expect(await installer.isInstalled(), isTrue);
    expect(await installer.isRunning(), isTrue);
    await installer.downloadModel(_model);
    expect(runner.commands.last, 'ollama pull $_model');
  });

  test('a failed model download throws', () async {
    final runner = _ScriptedRunner(exitCodes: {'ollama pull $_model': 1});

    expect(OllamaInstaller(runner).downloadModel(_model), throwsException);
  });
}
