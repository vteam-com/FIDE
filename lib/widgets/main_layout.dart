// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

// Providers
import '../providers/app_providers.dart';

// Screens
import '../screens/explorer_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/editor_screen.dart';
import '../screens/outline_panel.dart';

// Models
import '../models/file_system_item.dart';

// Utils
import '../utils/file_type_utils.dart';

// Widgets
import 'resizable_splitter.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Function(ThemeMode)? onThemeChanged;
  final Function(String)? onFileOpened;

  const MainLayout({super.key, this.onThemeChanged, this.onFileOpened});

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends ConsumerState<MainLayout> {
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
  List<String> mruFolders = [];
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
      mruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();
    });

    // Try to load the most recent folder if available
    if (mruFolders.isNotEmpty) {
      final success = await _tryLoadProject(mruFolders.first);
      if (success) {
        await tryReopenLastFile(mruFolders.first);
        return;
      }

      // Project failed to load, try the next one
      for (int i = 1; i < mruFolders.length; i++) {
        final success = await _tryLoadProject(mruFolders[i]);
        if (success) {
          await tryReopenLastFile(mruFolders[i]);
          return;
        }
      }

      // If we get here, all folders failed to load
      // Clear the MRU list
      setState(() {
        mruFolders.clear();
      });
      await _prefs.setStringList(_mruFoldersKey, mruFolders);
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
  Future<void> tryReopenLastFile(String projectPath) async {
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
  Future<void> pickDirectory() async {
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
            await tryReopenLastFile(selectedDirectory);
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
    final currentIndex = mruFolders.indexOf(directoryPath);

    if (currentIndex == 0) {
      // Already at the front, no need to update
      return;
    }

    if (currentIndex > 0) {
      // Move existing item to front
      mruFolders.removeAt(currentIndex);
    }

    // Add to front (whether it was existing or new)
    mruFolders.insert(0, directoryPath);

    if (mruFolders.length > _maxMruItems) {
      mruFolders = mruFolders.sublist(0, _maxMruItems);
    }

    // Ensure SharedPreferences is saved
    await _prefs.setStringList(_mruFoldersKey, mruFolders);

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
                          onOpenFolder: pickDirectory,
                          onCreateProject: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Create new project feature coming soon!',
                                ),
                              ),
                            );
                          },
                          mruFolders: mruFolders,
                          onOpenMruProject: (path) async {
                            final success = await _tryLoadProject(path);
                            if (success) {
                              await _updateMruList(path);
                              await tryReopenLastFile(path);
                            }
                          },
                          onRemoveMruEntry: (path) async {
                            setState(() {
                              mruFolders.remove(path);
                            });
                            await _prefs.setStringList(
                              _mruFoldersKey,
                              mruFolders,
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
