part of 'app_providers.dart';

/// The one owner of the project lifecycle: loading a project (after
/// unloading the open one), unloading it with its documents, and the
/// recent projects list. [ProjectService] does the loading steps.
class ProjectManager {
  final Logger _logger = Logger('ProjectManager');

  final Ref ref;

  /// Creates the manager reading its services and state through [ref].
  ProjectManager(this.ref);

  /// Unloads the open project, then loads the one at [directoryPath],
  /// logging the steps for the loading screen; a project that opens moves
  /// to the top of the recent projects. Returns whether it opened.
  Future<bool> loadProject(String directoryPath) async {
    final loading = ref.read(projectLoadingProvider.notifier)..state = true;
    try {
      if (ref.read(projectLoadedProvider)) unloadProject();
      final progress = ref.read(projectLoadProgressProvider)..start();
      final success = await ref
          .read(projectServiceProvider)
          .loadProject(directoryPath, progress);
      if (success) {
        await ref.read(mruFoldersProvider.notifier).touch(directoryPath);
      }
      return success;
    } catch (e) {
      _logger.severe('Error loading project: $e');
      return false;
    } finally {
      loading.state = false;
    }
  }

  /// Closes the open project and its documents.
  void unloadProject() {
    ref.read(projectServiceProvider).unloadProject();
    ref.read(openDocumentsProvider.notifier).closeAll();
  }

  /// Remembers [filePath] so [tryReopenLastFile] can restore it next time.
  Future<void> saveLastOpenedFile(String filePath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString(PrefKeys.lastOpenedFile, filePath);
    } catch (_) {
      // Silently handle SharedPreferences errors.
    }
  }

  /// Try to reopen the last opened file in the project.
  Future<void> tryReopenLastFile(String projectPath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastFilePath = prefs.getString(PrefKeys.lastOpenedFile);

      if (lastFilePath == null || lastFilePath.isEmpty) {
        return;
      }

      final file = File(lastFilePath);
      if (!await file.exists()) {
        return;
      }

      if (!p.isWithin(projectPath, lastFilePath)) {
        return;
      }

      if (!FileTypeUtils.isFileSupportedInEditor(lastFilePath)) {
        return;
      }

      if (!await ref
          .read(fileContentReaderProvider)
          .isWithinMaxSize(lastFilePath)) {
        return;
      }

      ref.read(selectedFileProvider.notifier).state = FileSystemItem.fromPath(
        lastFilePath,
      );
    } catch (_) {
      // Silently handle errors.
    }
  }
}
