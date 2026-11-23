import 'package:fide/models/local_model.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

/// Tag of the model picked by default.
final String _mimo = LocalModel.defaultModel.tag;

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

  String resolved = _mimo;

  @override
  String get model => resolved;

  @override
  bool get isFallbackModel => resolved != _mimo;

  @override
  Set<String> get downloaded => {resolved};

  @override
  Future<String?> resolveModel({AiCancelToken? cancel}) async => resolved;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('names an offered model by its label, a fallback as standing in', () {
    final preferred = OllamaModel(
      name: _mimo,
      isFallback: false,
      preferred: _mimo,
      downloaded: {_mimo},
    );
    final fallback = OllamaModel(
      name: 'llama3',
      isFallback: true,
      preferred: _mimo,
      downloaded: const {'llama3'},
    );

    expect(preferred.label, LocalModel.mimo.label);
    expect(fallback.label, 'llama3 (${LocalModel.mimo.label} not available)');
    expect(
      preferred,
      OllamaModel(
        name: _mimo,
        isFallback: false,
        preferred: _mimo,
        downloaded: {_mimo},
      ),
    );
    expect(preferred.hashCode, isNot(fallback.hashCode));
    expect(preferred.isInUse(LocalModel.mimo), isTrue);
    expect(fallback.isInUse(LocalModel.mimo), isFalse);
    expect(preferred.isDownloaded(LocalModel.mimo), isTrue);
    expect(fallback.isDownloaded(LocalModel.qwenCoder), isFalse);
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
    expect(container.read(ollamaModelProvider).name, _mimo);
    expect(container.read(ollamaModelProvider).preferred, _mimo);

    ai.resolved = 'llama3';
    container.invalidate(ollamaStatusProvider);
    await container.read(ollamaStatusProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(ollamaModelProvider).isFallback, isTrue);
    expect(container.read(ollamaModelProvider).downloaded, {'llama3'});
  });
}
