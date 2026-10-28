// ignore_for_file: avoid_print
// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/process_runner.dart';

/// Detects, installs and starts the local Ollama server and its model.
///
/// Kept apart from `AIService` so talking to the model and managing the
/// Ollama installation can change independently.
class OllamaInstaller {
  /// The model FIDE uses; other models such as `llama2` or `mistral` work too.
  static const String model = 'codellama';

  final ProcessRunner _runner;

  /// Creates an installer that launches commands through [_runner].
  const OllamaInstaller([this._runner = const ProcessRunner()]);

  /// Downloads [model].
  Future<void> downloadModel() async {
    final pullResult = await _runner.run('ollama', ['pull', model]);
    if (pullResult.exitCode != 0) {
      throw Exception('Failed to download $model model: ${pullResult.stderr}');
    }
  }

  /// Installs, starts and downloads whatever is missing; true when ready.
  Future<bool> ensureReady() async {
    try {
      if (!await isInstalled()) {
        print('⚠️  Ollama not installed, attempting installation...');
        await install();
        print('✅ Ollama installed successfully');
      }

      if (!await isRunning()) {
        print('🔄 Starting Ollama service...');
        await start();
        if (!await isRunning()) {
          throw Exception('Failed to start Ollama service');
        }
        print('✅ Ollama service started');
      }

      if (!await isModelInstalled()) {
        print('📥 Downloading $model model...');
        await downloadModel();
        print('✅ $model model downloaded');
      }

      return true;
    } catch (e) {
      print('❌ Failed to ensure Ollama readiness: $e');
      return false;
    }
  }

  /// Installs Ollama with the official script, then downloads [model].
  Future<void> install() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final installResult = await _runner.run('sh', [
        '-c',
        'curl -fsSL https://ollama.ai/install.sh | sh',
      ]);

      if (installResult.exitCode != 0) {
        throw Exception('Failed to install Ollama: ${installResult.stderr}');
      }

      await downloadModel();
    } else if (Platform.isWindows) {
      throw Exception(
        'Please install Ollama manually from https://ollama.ai/download for Windows.',
      );
    } else {
      throw Exception('Unsupported platform. Please install Ollama manually.');
    }
  }

  /// Whether the `ollama` executable is on the PATH.
  Future<bool> isInstalled() {
    return _runner.succeeds('which', ['ollama']);
  }

  /// Whether [model] has been downloaded.
  Future<bool> isModelInstalled() async {
    final models = await _runner.outputOf('ollama', ['list']);
    return models?.contains(model) ?? false;
  }

  /// Whether the Ollama server answers.
  Future<bool> isRunning() {
    return _runner.succeeds('ollama', ['list']);
  }

  /// Starts the Ollama server detached and gives it time to come up.
  Future<void> start() async {
    await _runner.start('ollama', ['serve'], mode: ProcessStartMode.detached);
    await Future.delayed(AppDuration.ollamaStartupDelay);
  }
}
