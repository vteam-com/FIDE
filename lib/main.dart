// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

// Providers
import 'providers/app_providers.dart';

// Widgets
import 'screens/main_layout.dart';
import 'widgets/title_bar.dart';

// Screens
import 'panels/center/editor_screen.dart';
import 'screens/welcome_screen.dart';

// Services
import 'services/git_service.dart';

// Theme
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        _loadingProjectName = directoryPath.split('/').last;
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
      debugPrint('Main: tryLoadProject error: $e');
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
      // Use ProjectService to load the project (this handles enumeration and watching)
      final projectService = container.read(projectServiceProvider);
      final success = await projectService.loadProject(projectPath);

      if (success) {
        debugPrint('Successfully auto-loaded MRU project: $projectPath');
      } else {
        debugPrint('Failed to auto-load MRU project: $projectPath');
      }
    } catch (e) {
      // Silently handle errors during auto-loading
      debugPrint('Error auto-loading MRU project: $e');
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
            // Custom title bar widget
            TitleBar(
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
            ),
            // Main content with menu bar
            Expanded(
              child: PlatformMenuBar(
                menus: [
                  PlatformMenu(
                    label: 'FIDE',
                    menus: [
                      PlatformMenuItem(
                        label: 'About',
                        onSelected: () {
                          showAboutDialog(
                            context: navigatorKey.currentContext ?? context,
                            applicationName: 'FIDE',
                            applicationVersion: '1.0.0',
                            applicationLegalese: '© 2025 FIDE',
                          );
                        },
                      ),
                      PlatformMenuItem(
                        label: 'Settings',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.comma,
                          meta: true,
                        ),
                        onSelected: () {
                          _showSettingsDialog(
                            navigatorKey.currentContext ?? context,
                          );
                        },
                      ),
                      PlatformMenuItem(
                        label: 'Quit FIDE',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyQ,
                          meta: true,
                        ),
                        onSelected: () {
                          SystemNavigator.pop();
                        },
                      ),
                    ],
                  ),
                  PlatformMenu(
                    label: 'File',
                    menus: [
                      PlatformMenuItem(
                        label: 'Open folder',
                        onSelected: () async {
                          triggerOpenFolder();
                        },
                      ),
                      PlatformMenuItem(
                        label: _getLastOpenedFileLabel(),
                        onSelected: () {
                          triggerReopenLastFile();
                        },
                      ),
                      PlatformMenuItemGroup(
                        members: [
                          PlatformMenuItem(
                            label: 'Initialize Repository',
                            onSelected: () async {
                              final currentPath = ref.read(
                                currentProjectPathProvider,
                              );
                              if (currentPath != null) {
                                final gitService = GitService();
                                final result = await gitService.initRepository(
                                  currentPath,
                                );
                                if (navigatorKey.currentContext != null) {
                                  ScaffoldMessenger.of(
                                    navigatorKey.currentContext!,
                                  ).showSnackBar(
                                    SnackBar(content: Text(result)),
                                  );
                                }
                              }
                            },
                          ),
                          PlatformMenuItem(
                            label: 'Refresh Status',
                            shortcut: const SingleActivator(
                              LogicalKeyboardKey.keyR,
                              meta: true,
                              shift: true,
                            ),
                            onSelected: () {
                              // This will be handled by the Git panel refresh
                            },
                          ),
                        ],
                      ),
                      PlatformMenuItemGroup(
                        members: [
                          PlatformMenuItem(
                            label: 'Save',
                            shortcut: const SingleActivator(
                              LogicalKeyboardKey.keyS,
                              meta: true,
                            ),
                            onSelected: () {
                              triggerSave();
                            },
                          ),
                          PlatformMenuItem(
                            label: 'Close Document',
                            shortcut: const SingleActivator(
                              LogicalKeyboardKey.keyW,
                              meta: true,
                            ),
                            onSelected: () {
                              triggerCloseDocument();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  PlatformMenu(
                    label: 'Edit',
                    menus: [
                      PlatformMenuItem(
                        label: 'Go to Line',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyG,
                          control: true,
                        ),
                        onSelected: () {
                          _showGotoLineDialog(
                            navigatorKey.currentContext ?? context,
                          );
                        },
                      ),
                    ],
                  ),
                  PlatformMenu(
                    label: 'View',
                    menus: [
                      PlatformMenuItem(
                        label: 'Panel Left',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.digit1,
                          meta: true,
                        ),
                        onSelected: () {
                          triggerTogglePanelLeft();
                        },
                      ),
                      PlatformMenuItem(
                        label: 'Panel Bottom',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.digit2,
                          meta: true,
                        ),
                        onSelected: () {
                          triggerTogglePanelBottom();
                        },
                      ),
                      PlatformMenuItem(
                        label: 'Panel Right',
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.digit3,
                          meta: true,
                        ),
                        onSelected: () {
                          triggerTogglePanelRight();
                        },
                      ),
                    ],
                  ),
                ],
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

                    if (!projectLoaded) {
                      // Show WelcomeScreen when no project is loaded
                      return WelcomeScreen(
                        onOpenFolder: pickDirectory,
                        onCreateProject: () {
                          // This would need to be implemented
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Create project not yet implemented',
                              ),
                            ),
                          );
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
                        isLoadingProject: _isLoadingProject,
                        loadingProjectName: _loadingProjectName,
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Theme'),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.system);
                  await _saveThemeMode(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.light);
                  await _saveThemeMode(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.dark);
                  await _saveThemeMode(ThemeMode.dark);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getLastOpenedFileLabel() {
    // Use the state variable that gets updated when files are opened
    if (_lastOpenedFileName != null) {
      return 'Last file opened: $_lastOpenedFileName';
    }
    return 'No file opened';
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
