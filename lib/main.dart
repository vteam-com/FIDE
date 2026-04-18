// ignore_for_file: use_build_context_synchronously
import 'package:fide/controllers/app_controller.dart';
import 'package:fide/controllers/project_operations.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/screens/create_project_screen.dart';
import 'package:fide/screens/loading_screen.dart';
import 'package:fide/screens/main_layout.dart';
import 'package:fide/screens/welcome_screen.dart';
import 'package:fide/widget_services/app_title_bar.dart';
import 'package:fide/widget_services/native_menu_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum for main view state
enum AppViewState {
  welcome, // Show WelcomeScreen
  createProject, // Show CreateProjectScreen
  loadingProject, // Show LoadingScreen for project loading
  mainLayout, // Show MainLayout (project loaded)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging
  Logger.root.level = Level.ALL;

  // Initialize app controller to handle setup
  final container = ProviderContainer();
  await container.read(appControllerProvider).initializeWindowManager();

  runApp(UncontrolledProviderScope(container: container, child: const FIDE()));
}

/// Root widget of the FIDE application.
class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

// Global functions for menu actions - now delegate to ProjectOperations service
/// Handles `triggerSave`.
void triggerSave() => ProjectOperations.triggerSave();

/// Handles `pickDirectoryAndLoadProject`.
Future<void> pickDirectoryAndLoadProject(BuildContext context, WidgetRef ref) =>
    ProjectOperations.pickDirectoryAndLoadProject(context, ref);

/// Handles `triggerOpenFolder`.
void triggerOpenFolder() => ProjectOperations.triggerOpenFolder();

/// Handles `triggerReopenLastFile`.
void triggerReopenLastFile() => ProjectOperations.triggerReopenLastFile();

/// Handles `triggerCloseDocument`.
void triggerCloseDocument() => ProjectOperations.triggerCloseDocument();

/// Handles `triggerSearch`.
void triggerSearch() => ProjectOperations.triggerSearch();

/// Handles `triggerSearchNext`.
void triggerSearchNext() => ProjectOperations.triggerSearchNext();

/// Handles `triggerSearchPrevious`.
void triggerSearchPrevious() => ProjectOperations.triggerSearchPrevious();

void Function(WidgetRef ref) triggerTogglePanelLeft = (ref) {
  final current = ref.read(leftPanelVisibleProvider);
  ref.read(leftPanelVisibleProvider.notifier).state = !current;
};

void Function(WidgetRef ref) triggerTogglePanelBottom = (ref) {
  final current = ref.read(bottomPanelVisibleProvider);
  ref.read(bottomPanelVisibleProvider.notifier).state = !current;
};

void Function(WidgetRef ref) triggerTogglePanelRight = (ref) {
  final current = ref.read(rightPanelVisibleProvider);
  ref.read(rightPanelVisibleProvider.notifier).state = !current;
};

class _FIDEState extends ConsumerState<FIDE> {
  final Logger _logger = Logger('_FIDEState');

  ThemeMode _themeMode = ThemeMode.system;
  String? _lastOpenedFileName;
  late SharedPreferences _prefs;
  static const String _themeModeKey = 'theme_mode';

  // Unified view state management
  AppViewState _currentViewState = AppViewState.welcome;

  // Loading state metadata (associated with view states)
  String? _loadingProjectName;

  void _clearCreatingState() {
    if (mounted) {
      setState(() {
        _currentViewState = AppViewState.mainLayout;
      });
    }
  }

  void _clearLoadingState() {
    if (mounted) {
      setState(() {
        _currentViewState = AppViewState.welcome;
        _loadingProjectName = null;
      });
    }
  }

  // Project loading function accessible by TitleBar
  /// Handles `_FIDEState.tryLoadProject`.
  Future<bool> tryLoadProject(String directoryPathToProject) async {
    try {
      // Set loading state
      setState(() {
        _currentViewState = AppViewState.loadingProject;
        _loadingProjectName = directoryPathToProject;
      });

      // Use the unified ProjectManager to handle everything
      final projectManager = ProviderScope.containerOf(
        context,
      ).read(projectManagerProvider);
      final success = await projectManager.loadProject(directoryPathToProject);

      // Clear loading state and set appropriate final state
      if (success) {
        // Project loaded successfully, switch to main layout
        if (mounted) {
          setState(() {
            _currentViewState = AppViewState.mainLayout;
            _loadingProjectName = null;
          });
        }
      } else {
        // Loading failed, back to welcome
        _clearLoadingState();
      }

      return success;
    } catch (e) {
      // Clear loading state on error
      _clearLoadingState();
      _logger.severe('tryLoadProject error: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initializes app services, restores settings, and attempts MRU auto-load.
  Future<void> _initializeApp() async {
    _prefs = await SharedPreferences.getInstance();

    // Call AppController to initialize theme and MRU folders (this will get code coverage)
    await ProviderScope.containerOf(
      context,
    ).read(appControllerProvider).initializeAppServices();

    // Initialize UI state with loaded values
    final savedThemeMode = _prefs.getString(_themeModeKey);
    if (savedThemeMode != null) {
      setState(() {
        _themeMode = _parseThemeMode(savedThemeMode);
      });
    }

    // Try to auto-load the first MRU project after initialization
    _tryAutoLoadFirstMruProject();
  }

  /// Schedules auto-loading of the first MRU project after startup.
  Future<void> _tryAutoLoadFirstMruProject() async {
    try {
      // Get current MRU folders from provider - they were loaded by AppController.initializeAppServices()
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final ref = ProviderScope.containerOf(context);
          final mruFolders = ref.read(mruFoldersProvider);

          if (mruFolders.isNotEmpty) {
            _tryLoadFirstMruProject(ref, mruFolders.first);
          }
        }
      });
    } catch (_) {
      // Silently handle errors during initialization
    }
  }

  /// Loads the first MRU project and updates loading and view state.
  Future<void> _tryLoadFirstMruProject(
    ProviderContainer container,
    String projectPath,
  ) async {
    try {
      // Set loading state before starting project load
      if (mounted) {
        setState(() {
          _currentViewState = AppViewState.loadingProject;
          _loadingProjectName = projectPath;
        });
      }

      // Use ProjectService to load the project (this handles enumeration and watching)
      final projectService = container.read(projectServiceProvider);
      final success = await projectService.loadProject(projectPath);

      // Clear loading state after auto-loading completes
      _clearLoadingState();

      if (success) {
        _logger.info('Successfully auto-loaded MRU project: $projectPath');
        // Set state to main layout since project loaded
        if (mounted) {
          setState(() {
            _currentViewState = AppViewState.mainLayout;
          });
        }
      } else {
        _logger.warning('Failed to auto-load MRU project: $projectPath');
        // Reset to welcome state on failure
        if (mounted) {
          setState(() {
            _currentViewState = AppViewState.welcome;
          });
        }
      }
    } catch (e) {
      // Clear loading state on error
      _clearLoadingState();
      // Silently handle errors during auto-loading
      _logger.severe('Error auto-loading MRU project: $e');
    }
  }

  /// Parses a persisted theme mode string into a [ThemeMode].
  ThemeMode _parseThemeMode(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    final themeString = themeMode.name; // 'light', 'dark', or 'system'
    await _prefs.setString(_themeModeKey, themeString);
  }

  void _updateTheme(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
    _saveThemeMode(themeMode);
  }

  // Helper functions for create project callbacks
  void _handleCreateProjectCancel() {
    setState(() {
      _currentViewState = AppViewState.welcome;
    });
  }

  /// Closes the active project and returns the app to the welcome screen.
  void _closeCurrentProject() {
    if (_currentViewState == AppViewState.mainLayout) {
      // Clear project state
      ProviderScope.containerOf(
        context,
      ).read(projectLoadedProvider.notifier).state = false;
      ProviderScope.containerOf(
        context,
      ).read(currentProjectPathProvider.notifier).state = null;
      ProviderScope.containerOf(
        context,
      ).read(selectedFileProvider.notifier).state = null;

      // Switch back to welcome state
      setState(() {
        _currentViewState = AppViewState.welcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: Column(
          children: [
            // Custom title bar widget - conditional based on screen
            Consumer(
              builder: (_, ref, _) {
                // Show TitleBar for all cases - it handles the logic internally
                return AppTitleBar(
                  themeMode: _themeMode,
                  onThemeChanged: (themeMode) => _updateTheme(themeMode),
                  onToggleLeftPanel: () => triggerTogglePanelLeft(ref),
                  onToggleBottomPanel: () => triggerTogglePanelBottom(ref),
                  onToggleRightPanel: () => triggerTogglePanelRight(ref),
                  leftPanelVisible: ref.watch(leftPanelVisibleProvider),
                  bottomPanelVisible: ref.watch(bottomPanelVisibleProvider),
                  rightPanelVisible: ref.watch(rightPanelVisibleProvider),
                  showPanelToggles:
                      _currentViewState == AppViewState.mainLayout,
                  onProjectSwitch: (projectPath) async {
                    await tryLoadProject(projectPath);
                  },
                  onProjectCreateComplete: () {
                    _clearCreatingState();
                  },
                  onShowCreateProjectScreen: () {
                    setState(() {
                      _currentViewState = AppViewState.createProject;
                    });
                  },
                  onCloseProject: _closeCurrentProject,
                );
              },
            ),
            // Main content with menu bar
            Expanded(
              child: PlatformMenuBar(
                menus: NativeMenuBuilder(
                  context: context,
                  ref: ref,
                  onOpenFolder: triggerOpenFolder,
                  onSave: triggerSave,
                  onCloseDocument: triggerCloseDocument,
                  onFind: triggerSearch,
                  onFindNext: triggerSearchNext,
                  onFindPrevious: triggerSearchPrevious,
                  onGoToLine: () => _showGotoLineDialog(
                    navigatorKey.currentContext ?? context,
                  ),
                  onToggleLeftPanel: () => triggerTogglePanelLeft(ref),
                  onToggleBottomPanel: () => triggerTogglePanelBottom(ref),
                  onToggleRightPanel: () => triggerTogglePanelRight(ref),
                  onSwitchPanel: (index) => _switchToPanel(ref, index),
                  onProjectSwitch: (path) async => await tryLoadProject(path),
                  onCloseProject: _closeCurrentProject,
                  lastOpenedFileName: _lastOpenedFileName,
                  onThemeChanged: (themeMode) => _updateTheme(themeMode),
                  currentThemeMode: _themeMode,
                ).buildMenus(),
                child: Consumer(
                  builder: (context, ref, _) {
                    final mruFolders = ref.watch(mruFoldersProvider);

                    // Project loading functions with access to ref
                    Future<void> pickDirectory() async {
                      await pickDirectoryAndLoadProject(context, ref);
                    }

                    // Determine the widget to show based on current state
                    final Widget content;
                    switch (_currentViewState) {
                      case AppViewState.createProject:
                        content = CreateProjectScreen(
                          onCancel: _handleCreateProjectCancel,
                          onOpenProject: tryLoadProject,
                        );
                        break;
                      case AppViewState.loadingProject:
                        content = LoadingScreen(
                          loadingProjectName: _loadingProjectName,
                        );
                        break;
                      case AppViewState.welcome:
                        content = WelcomeScreen(
                          onOpenFolder: pickDirectory,
                          onCreateProject: () {
                            _logger.fine('onCreateProject called');
                            setState(() {
                              _currentViewState = AppViewState.createProject;
                            });
                          },
                          mruFolders: mruFolders,
                          onOpenMruProject: tryLoadProject,
                          onRemoveMruEntry: (path) async {
                            final updatedMru = List<String>.from(mruFolders)
                              ..remove(path);
                            ref.read(mruFoldersProvider.notifier).state =
                                updatedMru;

                            // Save to SharedPreferences
                            try {
                              final prefs = await ref.read(
                                sharedPreferencesProvider.future,
                              );
                              await prefs.setStringList(
                                'mru_folders',
                                updatedMru,
                              );
                            } catch (_) {
                              // Silently handle SharedPreferences errors
                            }
                          },
                        );
                        break;
                      case AppViewState.mainLayout:
                        content = MainLayout(
                          onThemeChanged: (themeMode) =>
                              _updateTheme(themeMode),
                          onFileOpened: (fileName) {
                            setState(() => _lastOpenedFileName = fileName);
                          },
                        );
                        break;
                    }

                    return content;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the goto-line dialog and focuses its numeric input field.
  void _showGotoLineDialog(BuildContext context) {
    ProjectOperations.showGotoLineDialog(context);
  }

  void _switchToPanel(WidgetRef ref, int panelIndex) {
    // Use the provider to switch the active left panel tab
    // This will be picked up by the LeftPanel widget
    ref.read(activeLeftPanelTabProvider.notifier).state = panelIndex;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
