// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

// Screens
import 'screens/explorer/explorer_screen.dart';
import 'screens/explorer/welcome_screen.dart';
import 'screens/editor/editor_screen.dart';
import 'screens/outline/outline_panel.dart';

// Services
import 'services/file_system_service.dart';
import 'services/git_service.dart';

// Theme
import 'theme/app_theme.dart';

// Models
import 'models/file_system_item.dart';
import 'models/project_node.dart';

// Utils
import 'utils/file_type_utils.dart';

void main() {
  runApp(const ProviderScope(child: FIDE()));
}

class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

// Global functions for menu actions
void triggerSave() {
  // Call the static method to save the current editor
  EditorScreen.saveCurrentEditor();
}

void triggerOpenFolder() {
  // This will be set by MainLayout
  _mainLayoutKey.currentState?._pickDirectory();
}

void triggerReopenLastFile() {
  // This will be set by MainLayout
  _mainLayoutKey.currentState?._tryReopenLastFile(
    _mainLayoutKey.currentState?._mruFolders.first ?? '',
  );
}

// Global key to access MainLayout
final GlobalKey<_MainLayoutState> _mainLayoutKey =
    GlobalKey<_MainLayoutState>();

class _FIDEState extends ConsumerState<FIDE> {
  ThemeMode _themeMode = ThemeMode.system;
  String? _lastOpenedFileName;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      navigatorKey: navigatorKey,
      home: PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'File',
            menus: [
              PlatformMenuItem(
                label: 'Settings',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.comma,
                  meta: true,
                ),
                onSelected: () {
                  _showSettingsDialog(navigatorKey.currentContext ?? context);
                },
              ),
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
              PlatformMenuItemGroup(
                members: [
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
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  meta: true,
                  shift: true,
                ),
                onSelected: () {
                  triggerReopenLastFile();
                },
              ),
            ],
          ),
          PlatformMenu(
            label: 'Git',
            menus: [
              PlatformMenuItem(
                label: 'Initialize Repository',
                onSelected: () async {
                  final currentPath = ref.read(currentProjectPathProvider);
                  if (currentPath != null) {
                    final gitService = GitService();
                    final result = await gitService.initRepository(currentPath);
                    if (navigatorKey.currentContext != null) {
                      ScaffoldMessenger.of(
                        navigatorKey.currentContext!,
                      ).showSnackBar(SnackBar(content: Text(result)));
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
                  _showGotoLineDialog(navigatorKey.currentContext ?? context);
                },
              ),
            ],
          ),
          PlatformMenu(
            label: 'Help',
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
            ],
          ),
        ],
        child: MainLayout(
          key: _mainLayoutKey,
          onThemeChanged: (themeMode) {
            setState(() => _themeMode = themeMode);
          },
          onFileOpened: (fileName) {
            setState(() => _lastOpenedFileName = fileName);
          },
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
                onTap: () {
                  setState(() => _themeMode = ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () {
                  setState(() => _themeMode = ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () {
                  setState(() => _themeMode = ThemeMode.dark);
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

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((ref) => null);

// State management for project loading
final projectLoadedProvider = StateProvider<bool>((ref) => false);

// State management for current project path
final currentProjectPathProvider = StateProvider<String?>((ref) => null);

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((ref) => null);

// File system service provider
final fileSystemServiceProvider = Provider<FileSystemService>(
  (ref) => FileSystemService(),
);

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Try to get saved theme mode from shared preferences
  // For now, default to system
  return ThemeMode.system;
});

class MainLayout extends ConsumerStatefulWidget {
  final Function(ThemeMode)? onThemeChanged;
  final Function(String)? onFileOpened;

  const MainLayout({super.key, this.onThemeChanged, this.onFileOpened});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = 250.0;
  double _outlineWidth = 200.0;
  final double _minExplorerWidth = 150.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 400.0;

  // Active left panel view
  int _activeLeftPanel = 0; // 0 = Explorer, 1 = Git

  // Callback to refresh outline
  VoidCallback? _refreshOutlineCallback;

  // MRU (Most Recently Used) folders
  List<String> _mruFolders = [];
  static const String _mruFoldersKey = 'mru_folders';
  static const String _lastOpenedFileKey = 'last_opened_file';
  static const int _maxMruItems = 5;
  late SharedPreferences _prefs;
  String? _lastSelectedFilePath;

  @override
  void initState() {
    super.initState();
    _initializePrefsAndApp();
  }

  Future<void> _initializePrefsAndApp() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Load MRU folders and try to auto-load the most recent project
    await _loadMruFolders();

    // Listener will be set up in build method
  }

  // Method to set the outline refresh callback
  void _setOutlineRefreshCallback(VoidCallback callback) {
    _refreshOutlineCallback = callback;
  }

  void _onResize(double delta) {
    setState(() {
      _explorerWidth = (_explorerWidth + delta).clamp(
        _minExplorerWidth,
        _maxExplorerWidth,
      );
    });
  }

  void _onOutlineResize(double delta) {
    setState(() {
      _outlineWidth = (_outlineWidth - delta).clamp(
        _minOutlineWidth,
        _maxOutlineWidth,
      );
    });
  }

  // Load MRU folders and try to auto-load the most recent project
  Future<void> _loadMruFolders() async {
    final mruList = _prefs.getStringList(_mruFoldersKey) ?? [];

    // Keep all folders in MRU but check their access status
    setState(() {
      _mruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();
    });

    // Try to load the most recent folder if available
    if (_mruFolders.isNotEmpty) {
      final success = await _tryLoadProject(_mruFolders.first);
      if (success) {
        await _tryReopenLastFile(_mruFolders.first);
        return;
      }

      // Project failed to load, try the next one
      for (int i = 1; i < _mruFolders.length; i++) {
        final success = await _tryLoadProject(_mruFolders[i]);
        if (success) {
          await _tryReopenLastFile(_mruFolders[i]);
          return;
        }
      }

      // If we get here, all folders failed to load
      // Clear the MRU list
      setState(() {
        _mruFolders.clear();
      });
      await _prefs.setStringList(_mruFoldersKey, _mruFolders);
    }
  }

  // Try to load a project and return success status
  Future<bool> _tryLoadProject(String directoryPath) async {
    try {
      // Validate that this is a Flutter project
      final dir = Directory(directoryPath);
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      final libDir = Directory('${dir.path}/lib');

      if (!await pubspecFile.exists() || !await libDir.exists()) {
        return false;
      }

      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        return false;
      }

      // Load the project
      ref.read(projectLoadedProvider.notifier).state = true;
      ref.read(currentProjectPathProvider.notifier).state = directoryPath;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Try to reopen the last opened file if it exists and is a source file in the current project
  Future<void> _tryReopenLastFile(String projectPath) async {
    final lastFilePath = _prefs.getString(_lastOpenedFileKey);
    if (lastFilePath == null || lastFilePath.isEmpty) {
      return;
    }

    // Check if the file exists
    final file = File(lastFilePath);
    if (!await file.exists()) {
      return;
    }

    // Check if the file is in the current project
    if (!path.isWithin(projectPath, lastFilePath)) {
      return;
    }

    // Check if it's a source file
    if (!FileTypeUtils.isSourceFile(lastFilePath)) {
      return;
    }

    try {
      // Create FileSystemItem and set it as selected
      final fileSystemItem = FileSystemItem.fromFileSystemEntity(file);
      ref.read(selectedFileProvider.notifier).state = fileSystemItem;
    } catch (e) {
      // Silently handle errors
    }
  }

  // Method to pick directory - can be called from WelcomeScreen
  Future<void> _pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        // Validate that this is a Flutter project
        final dir = Directory(selectedDirectory);
        final pubspecFile = File('${dir.path}/pubspec.yaml');
        final libDir = Directory('${dir.path}/lib');

        if (await pubspecFile.exists() && await libDir.exists()) {
          final pubspecContent = await pubspecFile.readAsString();
          if (pubspecContent.contains('flutter:') ||
              pubspecContent.contains('sdk: flutter')) {
            // Load the project and update MRU
            await _updateMruList(selectedDirectory);
            ref.read(projectLoadedProvider.notifier).state = true;
            ref.read(currentProjectPathProvider.notifier).state =
                selectedDirectory;
            await _tryReopenLastFile(selectedDirectory);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected folder is not a valid Flutter project'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected folder is not a valid Flutter project'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
    }
  }

  // Update MRU list with a new project path
  Future<void> _updateMruList(String directoryPath) async {
    // Only update if this is a new directory or needs reordering
    final currentIndex = _mruFolders.indexOf(directoryPath);

    if (currentIndex == 0) {
      // Already at the front, no need to update
      return;
    }

    if (currentIndex > 0) {
      // Move existing item to front
      _mruFolders.removeAt(currentIndex);
    }

    // Add to front (whether it was existing or new)
    _mruFolders.insert(0, directoryPath);

    if (_mruFolders.length > _maxMruItems) {
      _mruFolders = _mruFolders.sublist(0, _maxMruItems);
    }

    // Ensure SharedPreferences is saved
    await _prefs.setStringList(_mruFoldersKey, _mruFolders);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);
    final projectLoaded = ref.watch(projectLoadedProvider);
    final currentProjectPath = ref.watch(currentProjectPathProvider);

    // Handle file selection changes
    if (selectedFile != null && selectedFile.path != _lastSelectedFilePath) {
      _prefs.setString(_lastOpenedFileKey, selectedFile.path);
      // Notify the parent widget about the file being opened (defer to avoid setState during build)
      final fileName = path.basename(selectedFile.path);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFileOpened?.call(fileName);
      });
      _lastSelectedFilePath = selectedFile.path;
    } else if (selectedFile == null && _lastSelectedFilePath != null) {
      _lastSelectedFilePath = null;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      body: Row(
        children: [
          // Left Panel - Explorer with Git toggle
          if (projectLoaded) ...[
            SizedBox(
              width: _explorerWidth,
              child: ExplorerScreen(
                onFileSelected: (file) {
                  ref.read(selectedFileProvider.notifier).state = file;
                },
                selectedFile: selectedFile,
                onThemeChanged: (themeMode) {
                  ref.read(themeModeProvider.notifier).state = themeMode;
                },
                onProjectLoaded: (loaded) {
                  ref.read(projectLoadedProvider.notifier).state = loaded;
                  if (!loaded) {
                    // Clear the current project path when unloaded
                    ref.read(currentProjectPathProvider.notifier).state = null;
                    // Clear the selected file when project is unloaded
                    ref.read(selectedFileProvider.notifier).state = null;
                  }
                },
                onProjectPathChanged: (path) {
                  // Update MRU list when a new project is loaded
                  _updateMruList(path);
                  ref.read(currentProjectPathProvider.notifier).state = path;
                },
                initialProjectPath: currentProjectPath,
                showGitPanel: _activeLeftPanel == 1,
                onToggleGitPanel: () {
                  setState(
                    () => _activeLeftPanel = _activeLeftPanel == 0 ? 1 : 0,
                  );
                },
              ),
            ),

            // Resizable Splitter
            ResizableSplitter(onResize: _onResize),
          ],

          // Main Editor Area
          Expanded(
            child: Row(
              children: [
                // Editor
                Expanded(
                  child: selectedFile != null
                      ? EditorScreen(
                          filePath: selectedFile.path,
                          onContentChanged: _refreshOutlineCallback,
                          onClose: () {
                            ref.read(selectedFileProvider.notifier).state =
                                null;
                          },
                        )
                      : !projectLoaded
                      ? WelcomeScreen(
                          onOpenFolder: _pickDirectory,
                          onCreateProject: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Create new project feature coming soon!',
                                ),
                              ),
                            );
                          },
                          mruFolders: _mruFolders,
                          onOpenMruProject: (path) async {
                            final success = await _tryLoadProject(path);
                            if (success) {
                              await _updateMruList(path);
                              await _tryReopenLastFile(path);
                            }
                          },
                          onRemoveMruEntry: (path) async {
                            setState(() {
                              _mruFolders.remove(path);
                            });
                            await _prefs.setStringList(
                              _mruFoldersKey,
                              _mruFolders,
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'Select a file to start editing',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                ),

                // Outline View
                if (selectedFile != null) ...[
                  // Resizable Splitter between Editor and Outline
                  ResizableSplitter(onResize: _onOutlineResize),
                  SizedBox(
                    width: _outlineWidth,
                    child: OutlinePanel(
                      file: selectedFile,
                      onOutlineUpdate: _setOutlineRefreshCallback,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResizableSplitter extends StatefulWidget {
  const ResizableSplitter({super.key, required this.onResize});

  final Function(double) onResize;

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _isDragging = false;

  bool _isHovering = false;

  double _startX = 0.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isHovering || _isDragging
          ? SystemMouseCursors.resizeLeftRight
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          setState(() {
            _isDragging = true;
            _startX = details.globalPosition.dx;
          });
        },
        onHorizontalDragUpdate: (details) {
          if (_isDragging) {
            final delta = details.globalPosition.dx - _startX;
            widget.onResize(delta);
            _startX = details.globalPosition.dx;
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
        },
        child: Container(
          width: 8,
          color: _isHovering || _isDragging
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _isHovering || _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
