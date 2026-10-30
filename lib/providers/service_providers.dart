import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/build_artifacts_inspector.dart';
import 'package:fide/providers/code_formatter.dart';
import 'package:fide/providers/code_review.dart';
import 'package:fide/providers/file_entry_service.dart';
import 'package:fide/providers/file_system_watcher.dart';
import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/project_analyzer.dart';
import 'package:fide/providers/project_categorizer.dart';
import 'package:fide/providers/project_creation_service.dart';
import 'package:fide/providers/project_maintenance_service.dart';
import 'package:fide/providers/project_overview_service.dart';
import 'package:fide/providers/project_search_service.dart';
import 'package:fide/providers/project_service.dart';
import 'package:fide/providers/project_tree_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Provides the [ProcessRunner] every service uses to launch commands;
/// override in tests to fake external tools.
final processRunnerProvider = Provider<ProcessRunner>(
  (_) => const ProcessRunner(),
);

/// Provides the shared [GitService]; override in tests to stub Git commands.
final gitServiceProvider = Provider<GitService>(
  (ref) => GitService(ref.read(processRunnerProvider)),
);

/// Provides the HTTP client network services send requests through;
/// override in tests with a `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Provides the shared [AIService]; override in tests to stub Ollama calls.
final aiServiceProvider = Provider<AIService>(
  (ref) =>
      AIService(ref.read(flutterSdkProvider), ref.read(httpClientProvider)),
);

/// Provides the [CodeReview] that runs fcheck for the AI reviews.
final codeReviewProvider = Provider<CodeReview>((_) => const CodeReview());

/// Provides the [OllamaInstaller] that installs and starts the local model.
final ollamaInstallerProvider = Provider<OllamaInstaller>(
  (ref) => OllamaInstaller(ref.read(processRunnerProvider)),
);

/// Provides the shared [LocalizationService] for project l10n setup.
final localizationServiceProvider = Provider<LocalizationService>(
  (ref) => LocalizationService(ref.read(processRunnerProvider)),
);

/// Provides the [FlutterBuildService] that runs build, clean and pod commands.
final flutterBuildServiceProvider = Provider<FlutterBuildService>(
  (ref) => FlutterBuildService(ref.read(processRunnerProvider)),
);

/// Provides the [BuildArtifactsInspector] the Execute panel reads build
/// output with.
final buildArtifactsInspectorProvider = Provider<BuildArtifactsInspector>(
  (_) => const BuildArtifactsInspector(),
);

/// Provides the [CodeFormatter] behind the editor's Format action.
final codeFormatterProvider = Provider<CodeFormatter>(
  (ref) => CodeFormatter(ref.read(processRunnerProvider)),
);

/// Provides the [FileEntryService] the tree panels create, rename and delete
/// entries with.
final fileEntryServiceProvider = Provider<FileEntryService>(
  (_) => const FileEntryService(),
);

/// Provides the [ProjectAnalyzer] that computes Info panel metrics.
final projectAnalyzerProvider = Provider<ProjectAnalyzer>(
  (_) => const ProjectAnalyzer(),
);

/// Provides the [ProjectCreationService] the new-project wizard runs.
final projectCreationServiceProvider = Provider<ProjectCreationService>(
  (ref) => ProjectCreationService(
    ref.read(processRunnerProvider),
    ref.read(gitServiceProvider),
    ref.read(localizationServiceProvider),
    ref.read(aiServiceProvider),
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
final arbServiceProvider = Provider<ArbService>((_) => ArbService());

/// Provides the [ProjectOverviewService] behind the center panel's project
/// overview.
final projectOverviewServiceProvider = Provider<ProjectOverviewService>(
  (ref) => ProjectOverviewService(
    ref.read(codeReviewProvider),
    ref.read(arbServiceProvider),
    ref.read(buildArtifactsInspectorProvider),
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
  (ref) => ProjectCategorizer(ref.read(projectTreeReaderProvider)),
);

/// Provides the [FileSystemWatcher] used for incremental project tree updates.
final fileSystemWatcherProvider = Provider<FileSystemWatcher>((ref) {
  final watcher = FileSystemWatcher(
    reader: ref.read(projectTreeReaderProvider),
  );
  ref.onDispose(watcher.dispose);
  return watcher;
});
