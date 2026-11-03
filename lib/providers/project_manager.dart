import 'package:fide/providers/mru_folders_notifier.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/services/loading_progress.dart';
import 'package:fide/services/project_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Provides the [ProjectManager] every open and close of a project goes
/// through.
final projectManagerProvider = Provider<ProjectManager>(
  (ref) => ProjectManager(
    service: ref.watch(projectServiceProvider),
    progress: ref.watch(projectLoadProgressProvider),
    recentFolders: ref.watch(mruFoldersProvider.notifier),
    documents: ref.watch(openDocumentsProvider.notifier),
    isLoaded: () => ref.read(projectLoadedProvider),
    setLoading: (loading) =>
        ref.read(projectLoadingProvider.notifier).state = loading,
  ),
);

/// The one owner of the project lifecycle: loading a project (after
/// unloading the open one), unloading it with its documents, and the
/// recent projects list. [ProjectService] does the loading steps.
class ProjectManager {
  final Logger _logger = Logger('ProjectManager');

  /// Creates the manager loading projects with [_service], reporting the
  /// steps to [_progress], remembering opened ones in [_recentFolders] and
  /// closing [_documents] with the project; [_isLoaded] says whether one
  /// is open and [_setLoading] whether one is loading.
  ProjectManager({
    required this._service,
    required this._progress,
    required this._recentFolders,
    required this._documents,
    required this._isLoaded,
    required this._setLoading,
  });

  /// The editor's documents, closed with the project.
  final OpenDocumentsNotifier _documents;

  /// Whether a project is open.
  final bool Function() _isLoaded;

  /// Reports the loading steps to the loading screen.
  final LoadingProgress _progress;

  /// The recent projects, which an opened project moves to the top of.
  final MruFoldersNotifier _recentFolders;

  /// Does the loading steps.
  final ProjectService _service;

  /// Marks a project as loading, or done loading.
  final void Function(bool loading) _setLoading;

  /// Unloads the open project, then loads the one at [directoryPath],
  /// logging the steps for the loading screen; a project that opens moves
  /// to the top of the recent projects. Returns whether it opened.
  Future<bool> loadProject(String directoryPath) async {
    _setLoading(true);
    try {
      if (_isLoaded()) unloadProject();
      _progress.start();
      final success = await _service.loadProject(directoryPath, _progress);
      if (success) await _recentFolders.touch(directoryPath);
      return success;
    } catch (e) {
      _logger.severe('Error loading project: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Closes the open project and its documents.
  void unloadProject() {
    _service.unloadProject();
    _documents.closeAll();
  }
}
