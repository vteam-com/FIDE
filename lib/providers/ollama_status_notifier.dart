import 'package:fide/models/ollama_step.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local Ollama setup, checked once for the app and kept, so an
/// install in progress survives hiding the AI panel or switching tabs.
final ollamaStatusProvider =
    AsyncNotifierProvider<OllamaStatusNotifier, OllamaStep>(
      OllamaStatusNotifier.new,
    );

/// Checks the Ollama setup and runs the step that completes it: install,
/// start or model download.
class OllamaStatusNotifier extends AsyncNotifier<OllamaStep> {
  OllamaInstaller get _installer => ref.read(ollamaInstallerProvider);

  @override
  Future<OllamaStep> build() => _check();

  /// Runs the action of the current step, then checks the setup again.
  /// Returns what was done; throws when the action fails. Does nothing
  /// while a step runs or once ready.
  Future<String?> fix() async {
    final step = state.value;
    final action = switch (step) {
      OllamaStep.notInstalled => _installer.install,
      OllamaStep.notRunning => _installer.start,
      OllamaStep.noModel => _installer.downloadModel,
      _ => null,
    };
    if (action == null) return null;

    state = const AsyncData(OllamaStep.installing);
    try {
      await action();
    } finally {
      state = AsyncData(await _check());
    }
    return switch (step) {
      OllamaStep.notInstalled =>
        'Ollama installed, ${OllamaInstaller.model} model downloaded, and service started.',
      OllamaStep.notRunning => 'Ollama started.',
      _ => '${OllamaInstaller.model} model downloaded.',
    };
  }

  /// The first missing piece of the setup, or [OllamaStep.ready].
  Future<OllamaStep> _check() async {
    try {
      if (!await _installer.isInstalled()) return OllamaStep.notInstalled;
      if (!await _installer.isRunning()) return OllamaStep.notRunning;
      final model = await ref.read(ollamaClientProvider).resolveModel();
      return model == null ? OllamaStep.noModel : OllamaStep.ready;
    } catch (_) {
      // Ollama not available
      return OllamaStep.notInstalled;
    }
  }
}
