part of 'app_providers.dart';

/// Represents `ProjectManager`.
class ProjectManager {
  final Logger _logger = Logger('ProjectManager');

  final Ref ref;

  ProjectManager(this.ref);

  /// Load a project with proper cleanup and MRU management.
  Future<bool> loadProject(String directoryPath) async {
    try {
      _logger.info('loadProject called with: $directoryPath');
      _logger.info('Loading project: $directoryPath');

      _logger.fine('Setting loading state to true');
      ref.read(projectLoadingProvider.notifier).state = true;

      final currentProjectLoaded = ref.read(projectLoadedProvider);
      _logger.fine('Current project loaded: $currentProjectLoaded');

      if (currentProjectLoaded) {
        _logger.info('Unloading current project first...');
        await unloadProject();
        _logger.info('Current project unloaded');
      }

      final projectService = ref.read(projectServiceProvider);
      final success = await projectService.loadProject(directoryPath);

      if (success) {
        _logger.info('Project loaded successfully');
        await _updateMruList(directoryPath);
        _logger.info('MRU list updated');
      }

      _logger.fine('Setting loading state to false');
      ref.read(projectLoadingProvider.notifier).state = false;

      return success;
    } catch (e) {
      _logger.severe('Error loading project: $e');
      ref.read(projectLoadingProvider.notifier).state = false;
      return false;
    }
  }

  /// Unload the current project.
  Future<void> unloadProject() async {
    try {
      _logger.info('Unloading project...');

      // Resets project path, root, loaded flag and selection via its sink
      final projectService = ref.read(projectServiceProvider);
      projectService.unloadProject();

      ref.read(openDocumentsProvider.notifier).state = [];
      ref.read(activeDocumentIndexProvider.notifier).state = -1;

      _logger.info('Project unloaded successfully');
    } catch (e) {
      _logger.severe('Error unloading project: $e');
    }
  }

  /// Update MRU list with the selected project at the top.
  Future<void> _updateMruList(String directoryPath) {
    return ref.read(mruFoldersProvider.notifier).touch(directoryPath);
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

      if (!await FileSystemItem.isWithinMaxFileSize(file)) {
        return;
      }

      ref.read(selectedFileProvider.notifier).state =
          FileSystemItem.forMruLoading(lastFilePath);
    } catch (_) {
      // Silently handle errors.
    }
  }
}
