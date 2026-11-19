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

  /// The operating system installed on, as `Platform.operatingSystem`
  /// names it: macOS and Linux install with Ollama's script, Windows by
  /// hand.
  final String operatingSystem;

  /// Creates an installer that launches commands through [_runner] on
  /// [operatingSystem] (the one FIDE runs on by default). Which steps run
  /// is the AI panel's `OllamaStatusNotifier`'s call.
  OllamaInstaller(this._runner, {String? operatingSystem})
    : operatingSystem = operatingSystem ?? Platform.operatingSystem;

  /// Downloads [AiModel.ollama].
  Future<void> downloadModel() async {
    await _runner.runChecked(
      'ollama',
      ['pull', AiModel.ollama],
      error: (result) => Exception(
        'Failed to download ${AiModel.ollama} model: ${result.stderr}',
      ),
    );
  }

  /// Installs Ollama with the official script, then downloads
  /// [AiModel.ollama].
  ///
  /// Throws on an [operatingSystem] the script does not support.
  Future<void> install() async {
    switch (FlutterPlatform.fromId(operatingSystem)) {
      case FlutterPlatform.macos || FlutterPlatform.linux:
        await _runner.runChecked(
          'sh',
          ['-c', 'curl -fsSL https://ollama.ai/install.sh | sh'],
          error: (result) =>
              Exception('Failed to install Ollama: ${result.stderr}'),
        );

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
