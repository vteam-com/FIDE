// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:fide/services/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

// Providers
import 'providers/app_providers.dart';

// Widgets
import 'screens/main_layout.dart';
import 'widgets/title_bar.dart';
import 'widgets/menu_builder.dart';

// Screens
import 'panels/center/editor_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';

// Services

// Theme
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: FIDE()));
}

class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

// Callbacks for updating visibility in FIDE state
VoidCallback? _onLeftPanelVisibilityChanged;
VoidCallback? _onBottomPanelVisibilityChanged;
VoidCallback? _onRightPanelVisibilityChanged;

// Global functions for menu actions
void triggerSave() {
  // Call the static method to save the current editor
  EditorScreen.saveCurrentEditor();
}

void triggerOpenFolder() {
  // This will be set by MainLayout
  _mainLayoutKey.currentState?.pickDirectory();
}

void triggerReopenLastFile() {
  // This will be set by MainLayout
  final currentProjectPath = _mainLayoutKey.currentState?.ref.read(
    currentProjectPathProvider,
  );
  if (currentProjectPath != null) {
    _mainLayoutKey.currentState?.tryReopenLastFile(currentProjectPath);
  }
}

void triggerCloseDocument() {
  // Call the static method to close the current editor
  EditorScreen.closeCurrentEditor();
}

void triggerSearch() {
  // Call the static method to toggle search in the current editor
  EditorScreen.toggleSearch();
}

void triggerSearchNext() {
  // Call the static method to toggle search in the current editor
  EditorScreen.findNext();
}

void triggerSearchPrevious() {
  // Call the static method to toggle search in the current editor
  EditorScreen.findPrevious();
}

void triggerTogglePanelLeft() {
  // Call the toggle left panel method on MainLayout
  _mainLayoutKey.currentState?.toggleLeftPanel();
  // Update visibility state
  _onLeftPanelVisibilityChanged?.call();
}

void triggerTogglePanelBottom() {
  // Call the toggle terminal method on MainLayout
  _mainLayoutKey.currentState?.toggleTerminalPanel();
  // Update visibility state
  _onBottomPanelVisibilityChanged?.call();
}

// Call the toggle outline method on MainLayout
void triggerTogglePanelRight() {
  _mainLayoutKey.currentState?.toggleOutlinePanel();
  // Update visibility state
  _onRightPanelVisibilityChanged?.call();
}

// Global key to access MainLayout
final GlobalKey<MainLayoutState> _mainLayoutKey = GlobalKey<MainLayoutState>();

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

  // Panel visibility states
  bool _leftPanelVisible = true;
  bool _bottomPanelVisible = true;
  bool _rightPanelVisible = true;

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
    _setupVisibilityCallbacks();
  }

  void _setupVisibilityCallbacks() {
    _onLeftPanelVisibilityChanged = () {
      setState(() {
        _leftPanelVisible = !_leftPanelVisible;
      });
    };
    _onBottomPanelVisibilityChanged = () {
      setState(() {
        _bottomPanelVisible = !_bottomPanelVisible;
      });
    };
    _onRightPanelVisibilityChanged = () {
      setState(() {
        _rightPanelVisible = !_rightPanelVisible;
      });
    };
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
                final projectLoaded = ref.watch(projectLoadedProvider);
                final isLoading = ref.watch(projectLoadingProvider);

                if (isLoading || !projectLoaded) {
                  // Show simplified title bar for welcome/loading screens
                  return _buildSimplifiedTitleBar();
                } else {
                  // Show full title bar for main layout
                  return TitleBar(
                    themeMode: _themeMode,
                    onThemeChanged: (themeMode) {
                      setState(() => _themeMode = themeMode);
                      _saveThemeMode(themeMode);
                    },
                    onToggleLeftPanel: triggerTogglePanelLeft,
                    onToggleBottomPanel: triggerTogglePanelBottom,
                    onToggleRightPanel: triggerTogglePanelRight,
                    leftPanelVisible: _leftPanelVisible,
                    bottomPanelVisible: _bottomPanelVisible,
                    rightPanelVisible: _rightPanelVisible,
                    onProjectSwitch: (projectPath) async {
                      await tryLoadProject(projectPath);
                    },
                  );
                }
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
                  onToggleLeftPanel: triggerTogglePanelLeft,
                  onToggleBottomPanel: triggerTogglePanelBottom,
                  onToggleRightPanel: triggerTogglePanelRight,
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
                      try {
                        final selectedDirectory = await FilePicker.platform
                            .getDirectoryPath();
                        if (selectedDirectory != null) {
                          // Use ProjectService to load the project
                          final projectService = ref.read(
                            projectServiceProvider,
                          );
                          final success = await projectService.loadProject(
                            selectedDirectory,
                          );

                          if (!success) {
                            // Show error if project loading failed
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to load project. Please ensure it is a valid Flutter project.',
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error loading project: $e')),
                        );
                      }
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
                          // Show dialog to get project name and location
                          final Map<String, String>? result =
                              await _showCreateProjectDialog(context);
                          if (result != null) {
                            final String projectName = result['name'] as String;
                            final String parentDirectory =
                                result['directory'] as String;

                            // Use ProjectService to create the project
                            final ProjectService projectService = ref.read(
                              projectServiceProvider,
                            );
                            final bool success = await projectService
                                .createProject(projectName, parentDirectory);

                            if (!success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to create project'),
                                ),
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
                        key: _mainLayoutKey,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid line number'),
          duration: Duration(seconds: 2),
        ),
      );
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

  Future<Map<String, String>?> _showCreateProjectDialog(
    BuildContext context,
  ) async {
    final TextEditingController nameController = TextEditingController();
    final directoryPath = (await getApplicationDocumentsDirectory()).path;
    final TextEditingController directoryController = TextEditingController(
      text: directoryPath,
    );
    String? selectedDirectory;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Flutter Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'Enter project name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: directoryController,
                      decoration: const InputDecoration(
                        labelText: 'Parent Directory',
                        hintText: 'Select parent directory',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final selectedDir = await FilePicker.platform
                          .getDirectoryPath();
                      if (selectedDir != null) {
                        selectedDirectory = selectedDir;
                        directoryController.text = selectedDir;
                      }
                    },
                    child: const Text('Browse'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                final directory = selectedDirectory ?? directoryController.text;
                if (nameController.text.isNotEmpty && directory.isNotEmpty) {
                  Navigator.of(
                    context,
                  ).pop({'name': nameController.text, 'directory': directory});
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _switchToPanel(WidgetRef ref, int panelIndex) {
    // Use the provider to switch the active left panel tab
    // This will be picked up by the LeftPanel widget
    ref.read(activeLeftPanelTabProvider.notifier).state = panelIndex;
  }

  Widget _buildSimplifiedTitleBar() {
    return GestureDetector(
      onDoubleTap: () async {
        final isMaximized = await windowManager.isMaximized();
        if (isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 40,
        color: _themeMode == ThemeMode.dark
            ? const Color(0xFF323233) // VS Code dark title bar color
            : const Color(0xFFECECEC), // VS Code light title bar color
        child: Row(
          children: [
            // Platform-specific spacing for window controls
            if (Platform.isMacOS)
              const SizedBox(
                width: 80,
              ), // Space for macOS traffic lights (left side)
            // Left section: Always show FIDE title
            Text(
              'FIDE - Flutter IDE',
              style: TextStyle(
                color: _themeMode == ThemeMode.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),

            // Spacer to push content away from right-side window controls (Windows/Linux)
            if (!Platform.isMacOS) const Spacer(),

            // Space for Windows/Linux window controls (right side)
            if (!Platform.isMacOS) const SizedBox(width: 120),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
