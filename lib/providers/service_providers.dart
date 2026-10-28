import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/file_system_watcher.dart';
import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/project_analyzer.dart';
import 'package:fide/providers/project_maintenance_service.dart';
import 'package:fide/providers/project_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [ProcessRunner] every service uses to launch commands;
/// override in tests to fake external tools.
final processRunnerProvider = Provider<ProcessRunner>(
  (_) => const ProcessRunner(),
);

/// Provides the shared [GitService]; override in tests to stub Git commands.
final gitServiceProvider = Provider<GitService>(
  (ref) => GitService(ref.read(processRunnerProvider)),
);

/// Provides the shared [AIService]; override in tests to stub Ollama calls.
final aiServiceProvider = Provider<AIService>(
  (ref) => AIService(ref.read(processRunnerProvider)),
);

/// Provides the shared [LocalizationService] for project l10n setup.
final localizationServiceProvider = Provider<LocalizationService>(
  (ref) => LocalizationService(ref.read(processRunnerProvider)),
);

/// Provides the [FlutterBuildService] that runs build, clean and pod commands.
final flutterBuildServiceProvider = Provider<FlutterBuildService>(
  (ref) => FlutterBuildService(ref.read(processRunnerProvider)),
);

/// Provides the [ProjectAnalyzer] that computes Info panel metrics.
final projectAnalyzerProvider = Provider<ProjectAnalyzer>(
  (_) => const ProjectAnalyzer(),
);

/// Provides the [ProjectMaintenanceService] for dependency and cleanup chores.
final projectMaintenanceServiceProvider = Provider<ProjectMaintenanceService>(
  (ref) => ProjectMaintenanceService(ref.read(processRunnerProvider)),
);

/// Provides the shared [ArbService] for reading and writing ARB files.
final arbServiceProvider = Provider<ArbService>((_) => ArbService());

/// Provides how `ProjectService` loads a project's file tree; tests override
/// it with [loadProjectTreeInline].
final projectTreeLoaderProvider = Provider<ProjectTreeLoader>(
  (_) => loadProjectTreeInIsolate,
);

/// Parent directory the new-project wizard starts in; null means the user's
/// documents directory.
final newProjectParentDirectoryProvider = Provider<String?>((_) => null);

/// Provides the [FileSystemWatcher] used for incremental project tree updates.
final fileSystemWatcherProvider = Provider<FileSystemWatcher>((ref) {
  final watcher = FileSystemWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});
