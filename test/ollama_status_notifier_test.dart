import 'package:fide/constants/constants.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/providers/local_model_notifier.dart';
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

/// An Ollama setup driven by flags; its actions complete the step they fix.
class _FakeInstaller extends OllamaInstaller {
  bool installed = false;
  bool running = false;
  final _FakeAi ai;
  int installs = 0;

  /// The models downloaded, by tag, in order.
  final List<String> pulls = [];

  _FakeInstaller(this.ai) : super(const ProcessRunner());

  @override
  Future<void> install(String model) async {
    installs++;
    installed = true;
    ai.pulled.add(model);
  }

  @override
  Future<void> downloadModel(String model) async {
    pulls.add(model);
    ai.pulled.add(model);
  }

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> start() async => running = true;
}

/// An Ollama client whose downloaded models are set by the test; it
/// resolves the preferred one when downloaded, else any.
class _FakeAi extends OllamaClient {
  _FakeAi() : super(http.Client());

  /// The models downloaded, by tag.
  final Set<String> pulled = {};

  @override
  Set<String> get downloaded => pulled;

  @override
  Future<String?> resolveModel({AiCancelToken? cancel}) async =>
      pulled.contains(preferred) ? preferred : pulled.firstOrNull;
}

void main() {
  late _FakeAi ai;
  late _FakeInstaller installer;
  late ProviderContainer container;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    final running = <bool>[];
    container
      ..listen(
        ollamaStatusProvider,
        (_, next) => steps.add(next.value),
        fireImmediately: false,
      )
      ..listen(
        ollamaSetupRunningProvider,
        (_, next) => running.add(next),
        fireImmediately: false,
      );

    final done = await container.read(ollamaStatusProvider.notifier).fix();

    expect(installer.installs, 1);
    expect(ai.pulled, {LocalModel.defaultModel.tag});
    expect(done, contains('installed'));
    expect(steps, [OllamaStep.notRunning]);
    expect(running, [true, false]);

    await container.read(ollamaStatusProvider.notifier).fix();
    expect(container.read(ollamaStatusProvider).value, OllamaStep.ready);
    expect(await container.read(ollamaStatusProvider.notifier).fix(), isNull);
  });

  test('the client prefers the model picked', () async {
    await container.read(ollamaStatusProvider.future);
    expect(ai.preferred, LocalModel.defaultModel.tag);

    await container
        .read(localModelProvider.notifier)
        .select(LocalModel.qwenCoder);
    await container.read(ollamaStatusProvider.future);

    expect(ai.preferred, LocalModel.qwenCoder.tag);
  });

  test('use downloads the model picked when Ollama runs without it', () async {
    installer
      ..installed = true
      ..running = true;
    ai.pulled.add(LocalModel.qwenCoder.tag);
    container.listen(ollamaStatusProvider, (_, _) {});
    await container.read(ollamaStatusProvider.future);

    final done = await container
        .read(ollamaStatusProvider.notifier)
        .use(LocalModel.qwen38);

    expect(done, '${LocalModel.qwen38.label} downloaded.');
    expect(installer.pulls, [LocalModel.qwen38.tag]);
    expect(container.read(localModelProvider), LocalModel.qwen38);
    expect(container.read(ollamaStatusProvider).value, OllamaStep.ready);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.localModel), LocalModel.qwen38.name);
  });

  test('use only picks a model downloaded, or with Ollama off', () async {
    container.listen(ollamaStatusProvider, (_, _) {});
    await container.read(ollamaStatusProvider.future);
    final notifier = container.read(ollamaStatusProvider.notifier);

    // Not installed: the install downloads the model picked
    expect(await notifier.use(LocalModel.qwen38), isNull);
    expect(container.read(localModelProvider), LocalModel.qwen38);

    installer
      ..installed = true
      ..running = true;
    ai.pulled.add(LocalModel.qwenCoder.tag);
    container.invalidate(ollamaStatusProvider);
    await container.read(ollamaStatusProvider.future);

    expect(await notifier.use(LocalModel.qwenCoder), isNull);
    expect(installer.pulls, isEmpty);
    expect(container.read(localModelProvider), LocalModel.qwenCoder);
  });
}
