import 'package:fide/models/app_view_state.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// What the window shows below the title bar; see [AppViewNotifier].
final appViewProvider = NotifierProvider<AppViewNotifier, AppViewState>(
  AppViewNotifier.new,
);

/// Why the last project the user asked for did not open, waiting to be
/// shown; the app clears it once shown.
final projectOpenErrorProvider = StateProvider<String?>((_ /*ref*/) => null);

/// Moves the app between its views: opening a project shows its loading
/// steps, then the IDE or, when it fails, the welcome screen; closing it
/// returns to the welcome screen. [ProjectManager] does the loading.
class AppViewNotifier extends Notifier<AppViewState> {
  /// Message shown when a picked folder is no Flutter project.
  static const String invalidProjectMessage =
      'Failed to load project. Please ensure it is a valid Flutter project.';

  /// The folder being loaded, while [AppViewState.loadingProject].
  String? _loadingProjectPath;

  /// The folder being loaded, while [AppViewState.loadingProject].
  String? get loadingProjectPath => _loadingProjectPath;

  @override
  AppViewState build() {
    // Closing the project, from any menu, leaves the IDE
    ref.listen(projectLoadedProvider, (_, loaded) {
      if (!loaded && state == AppViewState.mainLayout) {
        state = AppViewState.welcome;
      }
    });
    return ref.read(projectLoadedProvider)
        ? AppViewState.mainLayout
        : AppViewState.welcome;
  }

  /// Closes the open project and its documents.
  void closeProject() => ref.read(projectManagerProvider).unloadProject();

  /// Loads the project at [directoryPath], showing its loading steps, then
  /// the IDE or, when it fails, the welcome screen. Returns whether it
  /// opened.
  Future<bool> loadProject(String directoryPath) async {
    _loadingProjectPath = directoryPath;
    state = AppViewState.loadingProject;
    final opened = await ref
        .read(projectManagerProvider)
        .loadProject(directoryPath);
    if (ref.mounted) {
      _loadingProjectPath = null;
      state = opened ? AppViewState.mainLayout : AppViewState.welcome;
    }
    return opened;
  }

  /// Reopens the most recent project, if there is one.
  Future<void> openRecentProject() async {
    final recent = ref.read(mruFoldersProvider);
    if (recent.isNotEmpty) await loadProject(recent.first);
  }

  /// Asks for a folder and loads it as a project; a folder that does not
  /// open sets [projectOpenErrorProvider].
  Future<void> pickAndOpenProject() async {
    try {
      final folder = await FilePicker.getDirectoryPath();
      if (folder == null || await loadProject(folder)) return;
      _reportOpenError(invalidProjectMessage);
    } catch (e) {
      _reportOpenError('Error loading project: $e');
    }
  }

  /// Closes the open project and starts the new-project wizard.
  void showCreateProject() {
    closeProject();
    state = AppViewState.createProject;
  }

  /// Leaves the new-project wizard for the welcome screen.
  void showWelcome() => state = AppViewState.welcome;

  /// Hands [message] to the app to show, when the notifier is still alive.
  void _reportOpenError(String message) {
    if (ref.mounted) {
      ref.read(projectOpenErrorProvider.notifier).state = message;
    }
  }
}
