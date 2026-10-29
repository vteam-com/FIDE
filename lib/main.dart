// ignore_for_file: use_build_context_synchronously
import 'package:fide/controllers/app_controller.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/screens/create_project_screen.dart';
import 'package:fide/screens/loading_screen.dart';
import 'package:fide/screens/main_layout.dart';
import 'package:fide/screens/welcome_screen.dart';
import 'package:fide/widget_services/app_title_bar.dart';
import 'package:fide/widget_services/native_menu_builder.dart';
import 'package:fide/widgets/goto_line_dialog.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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

  String? _lastOpenedFileName;

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
      final projectManager = ref.read(projectManagerProvider);
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
    // Restores the theme and MRU folders into their providers
    await ref.read(appControllerProvider).initializeAppServices();

    // Try to auto-load the first MRU project after initialization
    _tryAutoLoadFirstMruProject();
  }

  /// Schedules auto-loading of the first MRU project after startup.
  Future<void> _tryAutoLoadFirstMruProject() async {
    try {
      // Get current MRU folders from provider - they were loaded by AppController.initializeAppServices()
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final mruFolders = ref.read(mruFoldersProvider);
          if (mruFolders.isNotEmpty) {
            tryLoadProject(mruFolders.first);
          }
        }
      });
    } catch (_) {
      // Silently handle errors during initialization
    }
  }

  /// Opens a folder picker and loads the chosen folder as a project.
  Future<void> _pickAndOpenProject() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory == null || !mounted) return;

      final success = await tryLoadProject(selectedDirectory);
      if (!success && mounted) {
        MessageBox.showError(
          navigatorKey.currentContext ?? context,
          'Failed to load project. Please ensure it is a valid Flutter project.',
        );
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(
          navigatorKey.currentContext ?? context,
          'Error loading project: $e',
        );
      }
    }
  }

  void _updateTheme(ThemeMode themeMode) {
    ref.read(appControllerProvider).setThemeMode(themeMode);
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
      ref.read(projectManagerProvider).unloadProject();

      // Switch back to welcome state
      setState(() {
        _currentViewState = AppViewState.welcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: Column(
          children: [
            // Custom title bar widget - conditional based on screen
            Consumer(
              builder: (_, ref, _) {
                // Show TitleBar for all cases - it handles the logic internally
                return AppTitleBar(
                  themeMode: themeMode,
                  onThemeChanged: (themeMode) => _updateTheme(themeMode),
                  onToggleLeftPanel: () => triggerTogglePanelLeft(ref),
                  onToggleBottomPanel: () => triggerTogglePanelBottom(ref),
                  onToggleRightPanel: () => triggerTogglePanelRight(ref),
                  leftPanelVisible: ref.watch(leftPanelVisibleProvider),
                  bottomPanelVisible: ref.watch(bottomPanelVisibleProvider),
                  rightPanelVisible: ref.watch(rightPanelVisibleProvider),
                  showPanelToggles:
                      _currentViewState == AppViewState.mainLayout,
                  onProjectSwitch: tryLoadProject,
                  onOpenFolder: _pickAndOpenProject,
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
                  onOpenFolder: _pickAndOpenProject,
                  onSave: ref.read(activeEditorProvider).save,
                  onCloseDocument: ref.read(activeEditorProvider).close,
                  onFind: ref.read(activeEditorProvider).toggleSearch,
                  onFindNext: ref.read(activeEditorProvider).findNext,
                  onFindPrevious: ref.read(activeEditorProvider).findPrevious,
                  onGoToLine: () => _showGotoLineDialog(
                    navigatorKey.currentContext ?? context,
                  ),
                  onToggleLeftPanel: () => triggerTogglePanelLeft(ref),
                  onToggleBottomPanel: () => triggerTogglePanelBottom(ref),
                  onToggleRightPanel: () => triggerTogglePanelRight(ref),
                  onSwitchPanel: (tab) => _switchToPanel(ref, tab),
                  onProjectSwitch: (path) async => await tryLoadProject(path),
                  onCloseProject: _closeCurrentProject,
                  lastOpenedFileName: _lastOpenedFileName,
                  onThemeChanged: (themeMode) => _updateTheme(themeMode),
                  currentThemeMode: themeMode,
                ).buildMenus(),
                child: Consumer(
                  builder: (_, ref, _) {
                    final mruFolders = ref.watch(mruFoldersProvider);

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
                          onOpenFolder: _pickAndOpenProject,
                          onCreateProject: () {
                            _logger.fine('onCreateProject called');
                            setState(() {
                              _currentViewState = AppViewState.createProject;
                            });
                          },
                          mruFolders: mruFolders,
                          accessibleFolders: ref.watch(
                            accessibleMruFoldersProvider,
                          ),
                          onOpenMruProject: tryLoadProject,
                          onRemoveMruEntry: ref
                              .read(mruFoldersProvider.notifier)
                              .remove,
                        );
                        break;
                      case AppViewState.mainLayout:
                        content = MainLayout(
                          onOpenProject: tryLoadProject,
                          onOpenFolder: _pickAndOpenProject,
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
    GotoLineDialog.show(context, ref.read(activeEditorProvider));
  }

  /// Shows [tab] in the left panel.
  void _switchToPanel(WidgetRef ref, LeftPanelTab tab) {
    ref.read(activeLeftPanelTabProvider.notifier).state = tab;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
