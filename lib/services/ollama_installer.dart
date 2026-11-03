import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/process_runner.dart';

/// Detects, installs and starts the local Ollama server and its model,
/// [AiModel.ollama].
///
/// Kept apart from `OllamaClient` so talking to the model and managing the
/// Ollama installation can change independently.
class OllamaInstaller {
  final ProcessRunner _runner;

  /// Receives each step of [ensureReady] as it happens.
  final ProcessOutputCallback onStep;

  /// The operating system installed on, as `Platform.operatingSystem`
  /// names it: macOS and Linux install with Ollama's script, Windows by
  /// hand.
  final String operatingSystem;

  /// Creates an installer that launches commands through [_runner] on
  /// [operatingSystem] (the one FIDE runs on by default), reporting its
  /// steps to [onStep] (ignored by default).
  OllamaInstaller(
    this._runner, {
    this.onStep = _ignoreStep,
    String? operatingSystem,
  }) : operatingSystem = operatingSystem ?? Platform.operatingSystem;

  /// Downloads [AiModel.ollama].
  Future<void> downloadModel() async {
    final pullResult = await _runner.run('ollama', ['pull', AiModel.ollama]);
    if (pullResult.exitCode != 0) {
      throw Exception(
        'Failed to download ${AiModel.ollama} model: ${pullResult.stderr}',
      );
    }
  }

  /// Installs, starts and downloads whatever is missing; true when ready.
  Future<bool> ensureReady() async {
    try {
      if (!await isInstalled()) {
        onStep('Ollama not installed, attempting installation...');
        await install();
        onStep('Ollama installed successfully');
      }

      if (!await isRunning()) {
        onStep('Starting Ollama service...');
        await start();
        if (!await isRunning()) {
          throw Exception('Failed to start Ollama service');
        }
        onStep('Ollama service started');
      }

      if (!await isModelInstalled()) {
        onStep('Downloading ${AiModel.ollama} model...');
        await downloadModel();
        onStep('${AiModel.ollama} model downloaded');
      }

      return true;
    } catch (e) {
      onStep('Failed to ensure Ollama readiness: $e');
      return false;
    }
  }

  /// Installs Ollama with the official script, then downloads
  /// [AiModel.ollama].
  ///
  /// Throws on an [operatingSystem] the script does not support.
  Future<void> install() async {
    switch (FlutterPlatform.fromId(operatingSystem)) {
      case FlutterPlatform.macos || FlutterPlatform.linux:
        final installResult = await _runner.run('sh', [
          '-c',
          'curl -fsSL https://ollama.ai/install.sh | sh',
        ]);

        if (installResult.exitCode != 0) {
          throw Exception('Failed to install Ollama: ${installResult.stderr}');
        }

        await downloadModel();
      case FlutterPlatform.windows:
        throw Exception(
          'Please install Ollama manually from https://ollama.ai/download for Windows.',
        );
      default:
        throw Exception(
          'Unsupported platform. Please install Ollama manually.',
        );
    }
  }

  /// Whether the `ollama` executable is on the PATH.
  Future<bool> isInstalled() {
    return _runner.succeeds('which', ['ollama']);
  }

  /// Whether [AiModel.ollama] has been downloaded.
  Future<bool> isModelInstalled() async {
    final models = await _runner.outputOf('ollama', ['list']);
    return models?.contains(AiModel.ollama) ?? false;
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

  /// The default [onStep], which drops the step.
  static void _ignoreStep(String _) {}
}
