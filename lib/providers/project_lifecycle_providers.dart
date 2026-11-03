import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/loading_progress.dart';
import 'package:fide/services/project_service.dart';
import 'package:fide/services/project_state_sink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'package:fide/models/loading_action.dart';

/// The file selected in the Explorer and shown in the editor, or null.
final selectedFileProvider = StateProvider<FileSystemItem?>((_) => null);

/// Whether a project is open.
final projectLoadedProvider = StateProvider<bool>((_) => false);

/// Root folder of the open project, or null without one.
final currentProjectPathProvider = StateProvider<String?>((_) => null);

/// File tree of the open project, or null without one.
final currentProjectRootProvider = StateProvider<ProjectNode?>((_) => null);

/// Bumped each time the current project tree changes in place (Git status,
/// file system events), so tree views rebuild even though the root object is
/// the same.
final projectTreeRevisionProvider = StateProvider<int>((_) => 0);

/// Whether a project is loading, for the loading screen.
final projectLoadingProvider = StateProvider<bool>((_) => false);

/// Provides the [ProjectService] doing `ProjectManager`'s loading steps;
/// it stops watching the project when the provider is disposed.
final projectServiceProvider = Provider<ProjectService>((ref) {
  final service = ProjectService(
    _ProviderProjectStateSink(ref),
    ref.read(gitServiceProvider),
    ref.read(fileSystemWatcherProvider),
    ref.read(projectConfigReaderProvider),
    loadTree: ref.read(projectTreeLoaderProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Reports the steps of loading a project to [loadingActionsProvider],
/// for the loading screen; override in tests to skip its pauses.
final projectLoadProgressProvider = Provider<LoadingProgress>(
  (ref) => LoadingProgress(
    (actions) => ref.read(loadingActionsProvider.notifier).state = actions,
  ),
);

/// Why the last project creation failed, waiting to be shown; the app
/// clears it once shown.
final projectCreationErrorProvider = StateProvider<String?>(
  (_ /*ref*/) => null,
);

/// The steps of the project being loaded or created, for the loading
/// screen.
final loadingActionsProvider = StateProvider<List<LoadingAction>>(
  (_ /*ref*/) => [],
);

/// Publishes the project state [ProjectService] reports to the providers
/// above.
class _ProviderProjectStateSink implements ProjectStateSink {
  final Ref _ref;

  _ProviderProjectStateSink(this._ref);

  @override
  void bumpProjectTreeRevision() {
    _ref.read(projectTreeRevisionProvider.notifier).state++;
  }

  @override
  void clearSelectedFile() {
    _ref.read(selectedFileProvider.notifier).state = null;
  }

  @override
  void setCurrentProjectPath(String? path) {
    _ref.read(currentProjectPathProvider.notifier).state = path;
  }

  @override
  void setCurrentProjectRoot(ProjectNode? root) {
    _ref.read(currentProjectRootProvider.notifier).state = root;
  }

  @override
  void setProjectLoaded(bool isLoaded) {
    _ref.read(projectLoadedProvider.notifier).state = isLoaded;
  }
}
