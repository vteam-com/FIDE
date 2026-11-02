import 'package:fide/models/create_project_draft.dart';
import 'package:fide/models/create_project_step.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/models/tool_availability.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/tool_availability_provider.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_creation_service.dart';
import 'package:fide/services/project_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

/// Records the request instead of creating anything, reporting the first
/// step done.
class _RecordingService extends ProjectCreationService {
  _RecordingService()
    : super(
        const ProcessRunner(),
        const GitService(ProcessRunner()),
        LocalizationService(const ProcessRunner(), const ProjectConfigReader()),
        ProjectTemplate(FakeChatModel(), const FlutterSdk(ProcessRunner())),
      );

  final List<ProjectCreationRequest> requests = [];

  @override
  Future<bool> create(
    ProjectCreationRequest request,
    CreationProgress onProgress,
  ) async {
    requests.add(request);
    onProgress(1, 'done', LoadingStatus.success);
    return true;
  }
}

void main() {
  const tools = ToolAvailability(
    flutterAvailable: true,
    gitVersion: '2.40.0',
    ollamaAvailable: true,
  );
  late _RecordingService service;
  late ProviderContainer container;

  setUp(() {
    service = _RecordingService();
    container = ProviderContainer(
      overrides: [
        toolAvailabilityProvider.overrideWith((_) async => tools),
        projectCreationServiceProvider.overrideWithValue(service),
        newProjectParentDirectoryProvider.overrideWithValue('/work'),
      ],
    );
    // Keep the auto-dispose draft alive between reads
    container.listen(createProjectDraftProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  CreateProjectDraftNotifier notifier() =>
      container.read(createProjectDraftProvider.notifier);
  CreateProjectDraft draft() => container.read(createProjectDraftProvider);

  test('resolves the configured parent directory', () async {
    await notifier().resolveParentDirectory('/elsewhere');

    expect(draft().parentDirectory, '/work');
  });

  test('stays on the details step until it has a name', () async {
    await notifier().resolveParentDirectory(null);

    await notifier().next();
    expect(draft().step, CreateProjectStep.nameAndFolder);

    notifier().setName('My App');
    await notifier().next();
    expect(draft().step, CreateProjectStep.localization);
    expect(draft().packageName, 'my_app');
    expect(draft().projectPath, '/work/my_app');
  });

  test('removing the default language picks another one', () {
    notifier().setDefaultLanguage('fr');
    notifier().setLanguage('fr', selected: false);
    expect(draft().defaultLanguage, 'en');

    notifier().setLanguage('en', selected: false);
    expect(draft().languages, {CreateProjectDraft.initialLanguage});
    expect(draft().defaultLanguage, CreateProjectDraft.initialLanguage);
  });

  test('creates the project with every choice of the draft', () async {
    await notifier().resolveParentDirectory(null);
    notifier()
      ..setName('demo')
      ..setUseAi(true)
      ..setDescription('  A recipe book  ')
      ..setLanguage('es', selected: true)
      ..setDefaultLanguage('es');
    await notifier().next();
    await notifier().next();

    final request = service.requests.single;
    expect(request.name, 'demo');
    expect(request.parentDirectory, '/work');
    expect(request.description, 'A recipe book');
    expect(request.defaultLanguage, 'es');
    expect(request.languages, {'en', 'fr', 'es'});
    expect(request.useAi, true);
    expect(request.initGit, true);
    expect(draft().step, CreateProjectStep.creating);
    expect(draft().created, true);
    expect(
      container.read(loadingActionsProvider).first.status,
      LoadingStatus.success,
    );
  });

  test('a request without AI or localization drops their choices', () {
    const choices = CreateProjectDraft(
      name: 'demo',
      parentDirectory: '/work',
      wantsLocalization: false,
      description: 'unused',
    );

    final request = choices.toRequest(
      const ToolAvailability(flutterAvailable: true),
    );

    expect(request.languages, null);
    expect(request.description, '');
    expect(request.useAi, false);
    expect(request.initGit, false);
  });
}
