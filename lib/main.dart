// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Controllers
import 'controllers/app_controller.dart';

// Providers
import 'providers/app_providers.dart';
import 'providers/ui_state_providers.dart';

// Services
import 'services/project_operations.dart';
import 'utils/message_box.dart';

// Widgets
import 'screens/create_project_screen.dart';
import 'widgets/app_title_bar.dart';
import 'widgets/menu_builder.dart';

// Screens
import 'screens/loading_screen.dart';
import 'screens/main_layout.dart';
import 'screens/welcome_screen.dart';
import 'panels/center/editor_screen.dart';

// Theme
import 'theme/app_theme.dart';

// Enum for main view state
enum AppViewState {
  welcome, // Show WelcomeScreen
  createProject, // Show CreateProjectScreen
  loadingProject, // Show LoadingScreen for project loading
  creatingProject, // Show LoadingScreen for project creation
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

class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

// Global functions for menu actions - now delegate to ProjectOperations service
void triggerSave() => ProjectOperations.triggerSave();

Future<void> pickDirectoryAndLoadProject(BuildContext context, WidgetRef ref) =>
    ProjectOperations.pickDirectoryAndLoadProject(context, ref);

void triggerOpenFolder() => ProjectOperations.triggerOpenFolder();

void triggerReopenLastFile() => ProjectOperations.triggerReopenLastFile();

void triggerCloseDocument() => ProjectOperations.triggerCloseDocument();

void triggerSearch() => ProjectOperations.triggerSearch();

void triggerSearchNext() => ProjectOperations.triggerSearchNext();

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
  String? _creatingProjectName;

  void _clearCreatingState() {
    if (mounted) {
      setState(() {
        _currentViewState = AppViewState.mainLayout;
        _creatingProjectName = null;
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
  Future<bool> tryLoadProject(String directoryPath) async {
    try {
      // Set loading state
      setState(() {
        _currentViewState = AppViewState.loadingProject;
        _loadingProjectName = directoryPath;
      });

      // Use the unified ProjectManager to handle everything
      final projectManager = ProviderScope.containerOf(
        context,
      ).read(projectManagerProvider);
      final success = await projectManager.loadProject(directoryPath);

      // Clear loading state
      _clearLoadingState();

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
    } catch (e) {
      // Silently handle errors during initialization
    }
  }

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

  void _handleCreateProject(Map<String, String> result) async {
    setState(() {
      _currentViewState = AppViewState.creatingProject;
      _creatingProjectName = result['name'];
    });

    try {
      final String projectName = result['name'] as String;
      final String parentDirectory = result['directory'] as String;

      _logger.info('Creating project: $projectName in $parentDirectory');

      // Use ProjectService to create the project
      final projectService = ProviderScope.containerOf(
        context,
      ).read(projectServiceProvider);
      final bool success = await projectService.createProject(
        projectName,
        parentDirectory,
      );

      _logger.info('Project creation success: $success');
      if (!success) {
        MessageBox.showError(context, 'Failed to create project');
      }
    } catch (e) {
      _logger.severe('Error creating project: $e');
      MessageBox.showError(
        context,
        'An error occurred while creating the project',
      );
    } finally {
      _clearCreatingState();
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
              builder: (context, ref, child) {
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
                  onProjectSwitch: (projectPath) async {
                    await tryLoadProject(projectPath);
                  },
                  onProjectCreateStart: (projectName) {
                    setState(() {
                      _currentViewState = AppViewState.creatingProject;
                      _creatingProjectName = projectName;
                    });
                  },
                  onProjectCreateComplete: () {
                    _clearCreatingState();
                  },
                  onShowCreateProjectScreen: () {
                    setState(() {
                      _currentViewState = AppViewState.createProject;
                    });
                  },
                );
              },
            ),
            // Main content with menu bar
            Expanded(
              child: PlatformMenuBar(
                menus: MenuBuilder(
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
                  lastOpenedFileName: _lastOpenedFileName,
                  onThemeChanged: (themeMode) => _updateTheme(themeMode),
                  currentThemeMode: _themeMode,
                ).buildMenus(),
                child: Consumer(
                  builder: (context, ref, child) {
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
                          onCreate: _handleCreateProject,
                        );
                        break;
                      case AppViewState.creatingProject:
                        content = LoadingScreen(
                          loadingProjectName: _creatingProjectName,
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
                            } catch (e) {
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

  void _handleGotoLine(String value, BuildContext context) {
    if (value.isEmpty) return;

    final lineNumber = int.tryParse(value);
    if (lineNumber != null && lineNumber > 0) {
      // Navigate to the line
      EditorScreen.navigateToLine(lineNumber);
      Navigator.of(context).pop();
    } else {
      // Show error for invalid input
      MessageBox.showError(context, 'Please enter a valid line number');
    }
  }

  void _showGotoLineDialog(BuildContext context) {
    final TextEditingController lineController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Go to Line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lineController,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Line number',
                  hintText: 'Enter line number',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  _handleGotoLine(value, context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _handleGotoLine(lineController.text, context);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    // Focus the text field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void _switchToPanel(WidgetRef ref, int panelIndex) {
    // Use the provider to switch the active left panel tab
    // This will be picked up by the LeftPanel widget
    ref.read(activeLeftPanelTabProvider.notifier).state = panelIndex;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
