import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/ai_assistant.dart';
import 'package:fide/services/app_icon_fixer.dart';
import 'package:fide/services/arb_key_remover.dart';
import 'package:fide/services/arb_migrator.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/asset_categorizer.dart';
import 'package:fide/services/build_artifacts_inspector.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/commit_message_writer.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/file_system_watcher.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_analyzer.dart';
import 'package:fide/services/project_categorizer.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_creation_service.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:fide/services/project_overview_service.dart';
import 'package:fide/services/project_search_service.dart';
import 'package:fide/services/project_service.dart';
import 'package:fide/services/project_template.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:fide/services/string_constants_extractor.dart';
import 'package:fide/services/string_localizer.dart';
import 'package:fide/services/test_suite_inspector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Asks the user for a folder; null when they cancel.
typedef FolderPicker = Future<String?> Function();

/// Finds the user's documents directory.
typedef DocumentsDirectoryFinder = Future<Directory> Function();

/// Provides the [ProcessRunner] every service uses to launch commands;
/// override in tests to fake external tools.
final processRunnerProvider = Provider<ProcessRunner>(
  (_) => const ProcessRunner(),
);

/// The operating system FIDE runs on, as [Platform.operatingSystem]
/// names it; override in tests to drive another platform's behaviour.
final hostOperatingSystemProvider = Provider<String>(
  (_) => Platform.operatingSystem,
);

/// Provides the [DesktopShell] of the platform FIDE runs on, chosen once.
final desktopShellProvider = Provider<DesktopShell>(
  (ref) => DesktopShell.forOperatingSystem(
    ref.read(hostOperatingSystemProvider),
    ref.read(processRunnerProvider),
  ),
);

/// Provides the [ProjectConfigReader] services read a project's pubspec,
/// `l10n.yaml` and platform folders with.
final projectConfigReaderProvider = Provider<ProjectConfigReader>(
  (_) => const ProjectConfigReader(),
);

/// The desktop platform FIDE runs on, which decides what it can build;
/// null on an OS Flutter does not target.
final hostPlatformProvider = Provider<FlutterPlatform?>(
  (ref) => FlutterPlatform.fromId(ref.read(hostOperatingSystemProvider)),
);

/// Provides the shared [GitService]; override in tests to stub Git commands.
final gitServiceProvider = Provider<GitService>(
  (ref) => GitService(
    ref.read(processRunnerProvider),
    reader: ref.read(fileContentReaderProvider),
    entries: ref.read(fileEntryServiceProvider),
  ),
);

/// Provides the HTTP client network services send requests through;
/// override in tests with a `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Provides the shared [OllamaClient], which picks the local model and
/// says whether it can call tools.
final ollamaClientProvider = Provider<OllamaClient>(
  (ref) => OllamaClient(ref.read(httpClientProvider)),
);

/// Provides the [ChatModel] every AI feature asks; override in tests with
/// a fake model.
final chatModelProvider = Provider<ChatModel>(
  (ref) => ref.read(ollamaClientProvider),
);

/// Provides the [AiAssistant] answering the AI panel's suggestions and
/// reviews.
final aiAssistantProvider = Provider<AiAssistant>(
  (ref) => AiAssistant(ref.read(chatModelProvider)),
);

/// Provides the [CommitMessageWriter] behind the Git panel's AI commit
/// message.
final commitMessageWriterProvider = Provider<CommitMessageWriter>(
  (ref) => CommitMessageWriter(ref.read(chatModelProvider)),
);

/// Provides the [ProjectTemplate] scaffolding the new-project wizard's
/// starter files.
final projectTemplateProvider = Provider<ProjectTemplate>(
  (ref) => ProjectTemplate(
    ref.read(chatModelProvider),
    ref.read(flutterSdkProvider),
  ),
);

/// Provides the [CodeReview] that runs fcheck for the AI reviews, the
/// overview and the quick fixes.
final codeReviewProvider = Provider<CodeReview>((_) => const CodeReview());

/// Provides the [OllamaInstaller] that installs and starts the local model.
final ollamaInstallerProvider = Provider<OllamaInstaller>(
  (ref) => OllamaInstaller(
    ref.read(processRunnerProvider),
    operatingSystem: ref.read(hostOperatingSystemProvider),
  ),
);

/// Provides the [L10nGenerator] running `flutter gen-l10n` for every
/// service that rewrites ARB files.
final l10nGeneratorProvider = Provider<L10nGenerator>(
  (ref) => L10nGenerator(ref.read(processRunnerProvider)),
);

/// Provides the shared [LocalizationSetup] for project l10n setup.
final localizationSetupProvider = Provider<LocalizationSetup>(
  (ref) => LocalizationSetup(
    ref.read(processRunnerProvider),
    ref.read(projectConfigReaderProvider),
    ref.read(l10nGeneratorProvider),
  ),
);

/// Provides the [StringLocalizer] behind the Localize strings quick fix.
final stringLocalizerProvider = Provider<StringLocalizer>(
  (ref) => StringLocalizer(
    ref.read(projectConfigReaderProvider),
    ref.read(l10nGeneratorProvider),
    ref.read(codeFormatterProvider),
  ),
);

/// Provides the [ArbMigrator] behind the Migrate to ARB quick fix.
final arbMigratorProvider = Provider<ArbMigrator>(
  (ref) => ArbMigrator(
    ref.read(processRunnerProvider),
    ref.read(projectConfigReaderProvider),
    ref.read(l10nGeneratorProvider),
    ref.read(codeFormatterProvider),
  ),
);

/// Provides the [ArbKeyRemover] behind the Remove unused keys quick fix.
final arbKeyRemoverProvider = Provider<ArbKeyRemover>(
  (ref) => ArbKeyRemover(
    ref.read(projectConfigReaderProvider),
    ref.read(l10nGeneratorProvider),
  ),
);

/// Provides the [ArbTranslator] behind Translate with AI and the
/// Localization panel's per-key translation.
final arbTranslatorProvider = Provider<ArbTranslator>(
  (ref) => ArbTranslator(
    ref.read(chatModelProvider),
    ref.read(projectConfigReaderProvider),
    ref.read(l10nGeneratorProvider),
  ),
);

/// Provides the [StringConstantsExtractor] behind the Make string
/// constants quick fix.
final stringConstantsExtractorProvider = Provider<StringConstantsExtractor>(
  (ref) => StringConstantsExtractor(
    ref.read(codeFormatterProvider),
    ref.read(projectConfigReaderProvider),
  ),
);

/// Provides the [FlutterBuildService] that runs build, clean and pod commands.
final flutterBuildServiceProvider = Provider<FlutterBuildService>(
  (ref) => FlutterBuildService(ref.read(processRunnerProvider)),
);

/// Provides the [TestSuiteInspector] the Test panel finds tests with.
final testSuiteInspectorProvider = Provider<TestSuiteInspector>(
  (_) => const TestSuiteInspector(),
);

/// Provides the [BuildArtifactsInspector] the Execute panel reads build
/// output with.
final buildArtifactsInspectorProvider = Provider<BuildArtifactsInspector>(
  (_) => const BuildArtifactsInspector(),
);

/// Provides the [AppIconFixer] behind the App Icons view's fixes.
final appIconFixerProvider = Provider<AppIconFixer>(
  (ref) => AppIconFixer(ref.read(projectConfigReaderProvider)),
);

/// Provides the [CodeFormatter] behind the editor's Format action.
final codeFormatterProvider = Provider<CodeFormatter>(
  (ref) => CodeFormatter(ref.read(processRunnerProvider)),
);

/// Provides the [FileContentReader] that loads files as text for the
/// editor and the outline.
final fileContentReaderProvider = Provider<FileContentReader>(
  (_) => const FileContentReader(),
);

/// Provides the [FileEntryService] the tree panels create, rename and delete
/// entries with.
final fileEntryServiceProvider = Provider<FileEntryService>(
  (_) => const FileEntryService(),
);

/// Provides the [ProjectAnalyzer] that computes Info panel metrics.
final projectAnalyzerProvider = Provider<ProjectAnalyzer>(
  (ref) => ProjectAnalyzer(ref.read(projectConfigReaderProvider)),
);

/// Provides the [ProjectCreationService] the new-project wizard runs.
final projectCreationServiceProvider = Provider<ProjectCreationService>(
  (ref) => ProjectCreationService(
    ref.read(processRunnerProvider),
    ref.read(gitServiceProvider),
    ref.read(localizationSetupProvider),
    ref.read(l10nGeneratorProvider),
    ref.read(projectTemplateProvider),
  ),
);

/// Provides the [ProjectMaintenanceService] for dependency and cleanup chores.
final projectMaintenanceServiceProvider = Provider<ProjectMaintenanceService>(
  (ref) => ProjectMaintenanceService(ref.read(processRunnerProvider)),
);

/// Provides the [FlutterSdk] probe for the installed Flutter and Dart versions.
final flutterSdkProvider = Provider<FlutterSdk>(
  (ref) => FlutterSdk(ref.read(processRunnerProvider)),
);

/// Provides the shared [ArbService] for reading and writing ARB files.
final arbServiceProvider = Provider<ArbService>((_) => const ArbService());

/// Provides the [ProjectOverviewService] behind the center panel's project
/// overview.
final projectOverviewServiceProvider = Provider<ProjectOverviewService>(
  (ref) => ProjectOverviewService(
    ref.read(codeReviewProvider),
    ref.read(arbServiceProvider),
    ref.read(buildArtifactsInspectorProvider),
    ref.read(projectConfigReaderProvider),
  ),
);

/// Provides how `ProjectService` loads a project's file tree; tests override
/// it with [loadProjectTreeInline].
final projectTreeLoaderProvider = Provider<ProjectTreeLoader>(
  (_) => loadProjectTreeInIsolate,
);

/// Parent directory the new-project wizard starts in; null means the user's
/// documents directory.
final newProjectParentDirectoryProvider = Provider<String?>((_) => null);

/// Provides the [FolderPicker] the Open Project actions ask for a folder
/// with; override in tests to answer without a dialog.
final folderPickerProvider = Provider<FolderPicker>(
  (_) => FilePicker.getDirectoryPath,
);

/// Provides the [DocumentsDirectoryFinder] the new-project wizard starts
/// in without a configured parent; override in tests to skip the platform.
final documentsDirectoryProvider = Provider<DocumentsDirectoryFinder>(
  (_) => getApplicationDocumentsDirectory,
);

/// Provides the [ProjectTreeReader] panels and the watcher read folders
/// with.
final projectTreeReaderProvider = Provider<ProjectTreeReader>(
  (_) => const ProjectTreeReader(),
);

/// Provides the [ProjectSearchService] behind the Search panel.
final projectSearchServiceProvider = Provider<ProjectSearchService>(
  (_) => const ProjectSearchService(),
);

/// Provides the [ProjectCategorizer] behind the Organized view.
final projectCategorizerProvider = Provider<ProjectCategorizer>(
  (ref) => ProjectCategorizer(
    ref.read(projectTreeReaderProvider),
    ref.read(assetCategorizerProvider),
  ),
);

/// Provides the [AssetCategorizer] grouping the Organized view's assets.
final assetCategorizerProvider = Provider<AssetCategorizer>(
  (ref) => AssetCategorizer(
    ref.read(projectTreeReaderProvider),
    ref.read(projectConfigReaderProvider),
  ),
);

/// Provides the [FileSystemWatcher] used for incremental project tree updates.
final fileSystemWatcherProvider = Provider<FileSystemWatcher>((ref) {
  final watcher = FileSystemWatcher(
    reader: ref.read(projectTreeReaderProvider),
  );
  ref.onDispose(watcher.dispose);
  return watcher;
});
