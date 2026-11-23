import 'package:fide/models/local_model.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/providers/local_model_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The local Ollama setup, checked once for the app and kept, so an
/// install in progress survives hiding the AI panel or switching tabs;
/// checked again when another model is picked.
final ollamaStatusProvider =
    AsyncNotifierProvider<OllamaStatusNotifier, OllamaStep>(
      OllamaStatusNotifier.new,
    );

/// Whether an Ollama install, start or model download is running, until
/// the setup is checked again. Kept apart from [ollamaStatusProvider] so
/// watching it, as the AI tab's ring does, never runs the setup check.
final ollamaSetupRunningProvider = StateProvider<bool>((_ /*ref*/) => false);

/// Checks the Ollama setup, with the model picked in [localModelProvider],
/// and runs the step that completes it: install, start or model download.
class OllamaStatusNotifier extends AsyncNotifier<OllamaStep> {
  OllamaInstaller get _installer => ref.read(ollamaInstallerProvider);

  /// The model picked, which the setup downloads.
  LocalModel get _picked => ref.read(localModelProvider);

  @override
  Future<OllamaStep> build() {
    ref.read(ollamaClientProvider).preferred = ref
        .watch(localModelProvider)
        .tag;
    return _check();
  }

  /// Runs the action of the current step, shown running through
  /// [ollamaSetupRunningProvider], then checks the setup again. Returns
  /// what was done; throws when the action fails. Does nothing while a
  /// step runs or once ready.
  Future<String?> fix() async {
    final model = _picked;
    return switch (state.value) {
      OllamaStep.notInstalled => _run(
        () => _installer.install(model.tag),
        'Ollama installed, ${model.label} downloaded, and service started.',
      ),
      OllamaStep.notRunning => _run(_installer.start, 'Ollama started.'),
      OllamaStep.noModel => _download(model),
      _ => null,
    };
  }

  /// Makes [model] the one the AI answers with, saved for the next
  /// launch, downloading it first when Ollama runs without it. Returns
  /// what was done, null when there was nothing to download; throws when
  /// the download fails.
  Future<String?> use(LocalModel model) async {
    final step = state.value;
    // Checks the setup again with it
    await ref.read(localModelProvider.notifier).select(model);
    final canDownload = step == OllamaStep.ready || step == OllamaStep.noModel;
    final client = ref.read(ollamaClientProvider);
    if (!canDownload || client.downloaded.contains(model.tag)) return null;
    return _download(model);
  }

  /// Downloads [model]; see [_run].
  Future<String?> _download(LocalModel model) => _run(
    () => _installer.downloadModel(model.tag),
    '${model.label} downloaded.',
  );

  /// Runs [action], shown running through [ollamaSetupRunningProvider],
  /// then checks the setup again; returns [done], or null without running
  /// it while another action runs. Throws when [action] fails.
  Future<String?> _run(Future<void> Function() action, String done) async {
    final running = ref.read(ollamaSetupRunningProvider.notifier);
    if (running.state) return null;
    running.state = true;
    try {
      await action();
    } finally {
      state = AsyncData(await _check());
      running.state = false;
    }
    return done;
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
