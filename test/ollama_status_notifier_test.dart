import 'package:fide/constants/constants.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// An Ollama setup driven by flags; its actions complete the step they fix.
class _FakeInstaller extends OllamaInstaller {
  bool installed = false;
  bool running = false;
  final _FakeAi ai;
  int installs = 0;

  _FakeInstaller(this.ai) : super(const ProcessRunner());

  @override
  Future<void> install() async {
    installs++;
    installed = true;
    ai.downloaded = AiModel.ollama;
  }

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> start() async => running = true;
}

/// An Ollama client whose downloaded model is set by the test.
class _FakeAi extends OllamaClient {
  _FakeAi() : super(http.Client());

  String? downloaded;

  @override
  Future<String?> resolveModel({AiCancelToken? cancel}) async => downloaded;
}

void main() {
  late _FakeAi ai;
  late _FakeInstaller installer;
  late ProviderContainer container;

  setUp(() {
    ai = _FakeAi();
    installer = _FakeInstaller(ai);
    container = ProviderContainer(
      overrides: [
        ollamaClientProvider.overrideWithValue(ai),
        ollamaInstallerProvider.overrideWithValue(installer),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('reports the first missing piece of the setup', () async {
    expect(
      await container.read(ollamaStatusProvider.future),
      OllamaStep.notInstalled,
    );

    installer
      ..installed = true
      ..running = true;
    container.invalidate(ollamaStatusProvider);
    expect(
      await container.read(ollamaStatusProvider.future),
      OllamaStep.noModel,
    );
  });

  test('fix runs the step, shows it in progress, then checks again', () async {
    await container.read(ollamaStatusProvider.future);
    final steps = <OllamaStep?>[];
    container.listen(
      ollamaStatusProvider,
      (_, next) => steps.add(next.value),
      fireImmediately: false,
    );

    final done = await container.read(ollamaStatusProvider.notifier).fix();

    expect(installer.installs, 1);
    expect(done, contains('installed'));
    expect(steps, [OllamaStep.installing, OllamaStep.notRunning]);

    await container.read(ollamaStatusProvider.notifier).fix();
    expect(container.read(ollamaStatusProvider).value, OllamaStep.ready);
    expect(await container.read(ollamaStatusProvider.notifier).fix(), isNull);
  });
}
