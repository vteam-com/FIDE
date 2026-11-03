import 'package:fide/constants/constants.dart';
import 'package:fide/models/ollama_model.dart';
import 'package:fide/providers/ollama_model_provider.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// An installed and running Ollama.
class _FakeInstaller extends OllamaInstaller {
  _FakeInstaller() : super(const ProcessRunner());

  @override
  Future<bool> isInstalled() async => true;

  @override
  Future<bool> isRunning() async => true;
}

/// An Ollama client whose resolved model is set by the test.
class _FakeAi extends OllamaClient {
  _FakeAi() : super(http.Client());

  String resolved = AiModel.ollama;

  @override
  String get model => resolved;

  @override
  bool get isFallbackModel => resolved != AiModel.ollama;

  @override
  Future<String?> resolveModel({AiCancelToken? cancel}) async => resolved;
}

void main() {
  test('labels a fallback model as standing in', () {
    const preferred = OllamaModel(name: AiModel.ollama, isFallback: false);
    const fallback = OllamaModel(name: 'llama3', isFallback: true);

    expect(preferred.label, AiModel.ollama);
    expect(fallback.label, 'llama3 (${AiModel.ollama} not available)');
    expect(
      preferred,
      const OllamaModel(name: AiModel.ollama, isFallback: false),
    );
    expect(preferred.hashCode, isNot(fallback.hashCode));
  });

  test('the provider follows the model each setup check resolves', () async {
    final ai = _FakeAi();
    final container = ProviderContainer(
      overrides: [
        ollamaClientProvider.overrideWithValue(ai),
        ollamaInstallerProvider.overrideWithValue(_FakeInstaller()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ollamaModelProvider, (_, _) {});

    await container.read(ollamaStatusProvider.future);
    expect(container.read(ollamaModelProvider).name, AiModel.ollama);

    ai.resolved = 'llama3';
    container.invalidate(ollamaStatusProvider);
    await container.read(ollamaStatusProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(ollamaModelProvider).isFallback, isTrue);
  });
}
