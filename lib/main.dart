// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

// Controllers
import 'controllers/app_controller.dart';

// Providers
import 'providers/app_providers.dart';
import 'providers/ui_state_providers.dart';

// Services
import 'services/project_service.dart';
import 'services/project_operations.dart';
import 'utils/message_helper.dart';

// Widgets
import 'widgets/create_project_dialog.dart';
import 'widgets/title_bar.dart';
import 'widgets/menu_builder.dart';

// Screens
import 'screens/loading_screen.dart';
import 'screens/main_layout.dart';
import 'screens/welcome_screen.dart';
import 'panels/center/editor_screen.dart';

// Theme
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Initialize app controller to handle setup
  final container = ProviderContainer();
  await container.read(appControllerProvider).initialize();

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

class WindowControls extends StatelessWidget {
  const WindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.minimize, size: 16),
          onPressed: () async {
            await windowManager.minimize();
          },
          tooltip: 'Minimize',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            foregroundColor: isDark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.crop_square, size: 16),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          tooltip: 'Maximize/Restore',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            foregroundColor: isDark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: () async {
            await windowManager.close();
          },
          tooltip: 'Close',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          hoverColor: isDark ? Colors.red[900] : Colors.red[100],
          style: IconButton.styleFrom(
            foregroundColor: isDark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

class _FIDEState extends ConsumerState<FIDE> {
  final Logger _logger = Logger('_FIDEState');

  ThemeMode _themeMode = ThemeMode.system;
  String? _lastOpenedFileName;
  late SharedPreferences _prefs;
  static const String _themeModeKey = 'theme_mode';

  // Loading state for project loading
  bool _isLoadingProject = false;
  String? _loadingProjectName;

  // Project loading function accessible by TitleBar
  Future<bool> tryLoadProject(String directoryPath) async {
    try {
      // Set loading state
      setState(() {
        _isLoadingProject = true;
        _loadingProjectName = directoryPath;
      });

      // Use the unified ProjectManager to handle everything
      final projectManager = ProviderScope.containerOf(
        context,
      ).read(projectManagerProvider);
      final success = await projectManager.loadProject(directoryPath);

      // Clear loading state
      if (mounted) {
        setState(() {
          _isLoadingProject = false;
          _loadingProjectName = null;
        });
      }

      return success;
    } catch (e) {
      // Clear loading state on error
      if (mounted) {
        setState(() {
          _isLoadingProject = false;
          _loadingProjectName = null;
        });
      }
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

    // Initialize theme
    final savedThemeMode = _prefs.getString(_themeModeKey);
    if (savedThemeMode != null) {
      setState(() {
        _themeMode = _parseThemeMode(savedThemeMode);
      });
    }

    // Load MRU folders at app startup
    await _loadMruFoldersAtStartup();
  }

  Future<void> _loadMruFoldersAtStartup() async {
    try {
      final mruList = _prefs.getStringList('mru_folders') ?? [];

      // Filter out folders that don't exist
      final validMruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();

      // Update the provider with loaded MRU folders
      // We need to use a post-frame callback to ensure the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final ref = ProviderScope.containerOf(context);
          ref.read(mruFoldersProvider.notifier).state = validMruFolders;

          // If there are MRU folders, try to load the first one automatically
          if (validMruFolders.isNotEmpty) {
            _tryLoadFirstMruProject(ref, validMruFolders.first);
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
          _isLoadingProject = true;
          _loadingProjectName = projectPath;
        });
      }

      // Use ProjectService to load the project (this handles enumeration and watching)
      final projectService = container.read(projectServiceProvider);
      final success = await projectService.loadProject(projectPath);

      // Clear loading state after auto-loading completes
      if (mounted) {
        setState(() {
          _isLoadingProject = false;
          _loadingProjectName = null;
        });
      }

      if (success) {
        _logger.info('Successfully auto-loaded MRU project: $projectPath');
      } else {
        _logger.warning('Failed to auto-load MRU project: $projectPath');
      }
    } catch (e) {
      // Clear loading state on error
      if (mounted) {
        setState(() {
          _isLoadingProject = false;
          _loadingProjectName = null;
        });
      }
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
                return TitleBar(
                  themeMode: _themeMode,
                  onThemeChanged: (themeMode) {
                    setState(() => _themeMode = themeMode);
                    _saveThemeMode(themeMode);
                  },
                  onToggleLeftPanel: () => triggerTogglePanelLeft(ref),
                  onToggleBottomPanel: () => triggerTogglePanelBottom(ref),
                  onToggleRightPanel: () => triggerTogglePanelRight(ref),
                  leftPanelVisible: ref.watch(leftPanelVisibleProvider),
                  bottomPanelVisible: ref.watch(bottomPanelVisibleProvider),
                  rightPanelVisible: ref.watch(rightPanelVisibleProvider),
                  onProjectSwitch: (projectPath) async {
                    await tryLoadProject(projectPath);
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
                  onThemeChanged: (themeMode) {
                    setState(() => _themeMode = themeMode);
                    _saveThemeMode(themeMode);
                  },
                  currentThemeMode: _themeMode,
                ).buildMenus(),
                child: Consumer(
                  builder: (context, ref, child) {
                    final projectLoaded = ref.watch(projectLoadedProvider);
                    final mruFolders = ref.watch(mruFoldersProvider);

                    // Project loading functions with access to ref
                    Future<void> pickDirectory() async {
                      await pickDirectoryAndLoadProject(context, ref);
                    }

                    if (_isLoadingProject) {
                      // Show LoadingScreen when project is being loaded
                      return LoadingScreen(
                        loadingProjectName: _loadingProjectName,
                      );
                    } else if (!projectLoaded) {
                      // Show WelcomeScreen when no project is loaded
                      return WelcomeScreen(
                        onOpenFolder: pickDirectory,
                        onCreateProject: () async {
                          debugPrint('onCreateProject called');
                          // Show dialog to get project name and location
                          final Map<String, String>? result =
                              await showCreateProjectDialog(context);
                          debugPrint('Dialog result: $result');
                          if (result != null) {
                            final String projectName = result['name'] as String;
                            final String parentDirectory =
                                result['directory'] as String;

                            debugPrint(
                              'Creating project: $projectName in $parentDirectory',
                            );
                            // Use ProjectService to create the project
                            final ProjectService projectService = ref.read(
                              projectServiceProvider,
                            );
                            final bool success = await projectService
                                .createProject(projectName, parentDirectory);

                            debugPrint('Project creation success: $success');
                            if (!success) {
                              MessageHelper.showError(
                                context,
                                'Failed to create project',
                              );
                            }
                          }
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
                    } else {
                      // Show main layout when project is loaded
                      return MainLayout(
                        onThemeChanged: (themeMode) {
                          setState(() => _themeMode = themeMode);
                        },
                        onFileOpened: (fileName) {
                          setState(() => _lastOpenedFileName = fileName);
                        },
                      );
                    }
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
      MessageHelper.showError(context, 'Please enter a valid line number');
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
