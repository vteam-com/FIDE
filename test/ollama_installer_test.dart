import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each command line from [exitCodes] (0 when unlisted), recording
/// the command lines run; `ollama list` outputs [models].
class _ScriptedRunner extends ProcessRunner {
  final Map<String, int> exitCodes;
  final String models;
  final List<String> commands = [];

  _ScriptedRunner({this.exitCodes = const {}, this.models = ''});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    final exitCode = exitCodes[command] ?? 0;
    return ProcessResult(
      0,
      exitCode,
      command == 'ollama list' ? models : '',
      '',
    );
  }
}

void main() {
  test('installs with the script on macOS and Linux, then downloads', () async {
    for (final os in ['macos', 'linux']) {
      final runner = _ScriptedRunner();
      final installer = OllamaInstaller(runner, operatingSystem: os);

      await installer.install();

      expect(runner.commands, [
        'sh -c curl -fsSL https://ollama.ai/install.sh | sh',
        'ollama pull ${AiModel.ollama}',
      ]);
    }
  });

  test('asks for a manual install on Windows and unknown systems', () async {
    for (final os in ['windows', 'fuchsia']) {
      final runner = _ScriptedRunner();
      final installer = OllamaInstaller(runner, operatingSystem: os);

      await expectLater(installer.install(), throwsException);
      expect(runner.commands, isEmpty);
    }
  });

  test('defaults to the operating system FIDE runs on', () {
    expect(
      OllamaInstaller(_ScriptedRunner()).operatingSystem,
      Platform.operatingSystem,
    );
  });

  test('ensureReady reports each step and downloads the model', () async {
    final runner = _ScriptedRunner();
    final steps = <String>[];
    final installer = OllamaInstaller(
      runner,
      operatingSystem: 'linux',
      onStep: steps.add,
    );

    expect(await installer.isInstalled(), isTrue);
    expect(await installer.isRunning(), isTrue);
    expect(await installer.isModelInstalled(), isFalse);
    expect(await installer.ensureReady(), isTrue);
    expect(steps, [
      'Downloading ${AiModel.ollama} model...',
      '${AiModel.ollama} model downloaded',
    ]);
    expect(runner.commands.last, 'ollama pull ${AiModel.ollama}');
  });

  test('ensureReady is false when a download fails', () async {
    final runner = _ScriptedRunner(
      exitCodes: {'ollama pull ${AiModel.ollama}': 1},
    );
    final steps = <String>[];
    final installer = OllamaInstaller(runner, onStep: steps.add);

    expect(await installer.ensureReady(), isFalse);
    expect(steps.last, startsWith('Failed to ensure Ollama readiness'));
    expect(installer.downloadModel(), throwsException);
  });

  test('ensureReady is already satisfied with the model listed', () async {
    final runner = _ScriptedRunner(models: '${AiModel.ollama}:latest');
    final installer = OllamaInstaller(runner);

    expect(await installer.ensureReady(), isTrue);
    expect(runner.commands, isNot(contains('ollama pull ${AiModel.ollama}')));
  });
}
