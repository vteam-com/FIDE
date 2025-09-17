// ignore_for_file: use_build_context_synchronously

import 'package:fide/screens/editor_screen.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

// Providers
import '../providers/app_providers.dart';

// Screens - Now handled by panel components

// Models
import '../models/file_system_item.dart';

// Utils
import '../utils/file_type_utils.dart';

// Widgets
import 'resizable_splitter.dart';
import 'left_panel.dart';
import 'center_panel.dart';
import 'right_panel.dart';

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
  final double _minExplorerWidth = 200.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 400.0;

  // Active left panel view
  int _activeLeftPanel = 0; // 0 = Explorer, 1 = Git

  // Callback to refresh outline
  VoidCallback? _refreshOutlineCallback;

  static const String _lastOpenedFileKey = 'last_opened_file';
  static const String _mruFoldersKey = 'mru_folders';
  String? _lastSelectedFilePath;

  @override
  void initState() {
    super.initState();
    _initializePrefsAndApp();
  }

  Future<void> _initializePrefsAndApp() async {
    // Load MRU folders into provider and try auto-loading
    await _loadMruFoldersIntoProvider();
  }

  // Load MRU folders into provider and try auto-loading most recent project
  Future<void> _loadMruFoldersIntoProvider() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final mruList = prefs.getStringList(_mruFoldersKey) ?? [];

      // Filter out folders that don't exist
      final validMruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();

      // Update the provider with loaded MRU folders
      ref.read(mruFoldersProvider.notifier).state = validMruFolders;

      // Try to auto-load the most recent project
      if (validMruFolders.isNotEmpty) {
        await _tryAutoLoadProject(validMruFolders.first);
      }
    } catch (e) {
      // Silently handle errors during initialization
    }
  }

  // Try to auto-load a project and reopen last file
  Future<void> _tryAutoLoadProject(String directoryPath) async {
    try {
      // Validate that this is a Flutter project
      final dir = Directory(directoryPath);
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      final libDir = Directory('${dir.path}/lib');

      if (!await pubspecFile.exists() || !await libDir.exists()) {
        return;
      }

      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        return;
      }

      // Load the project
      ref.read(projectLoadedProvider.notifier).state = true;
      ref.read(currentProjectPathProvider.notifier).state = directoryPath;

      // Try to reopen the last file
      await tryReopenLastFile(directoryPath);
    } catch (e) {
      // Silently handle errors
    }
  }

  // Try to reopen the last opened file
  Future<void> tryReopenLastFile(String projectPath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastFilePath = prefs.getString(_lastOpenedFileKey);

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

      // Create FileSystemItem and set it as selected
      final fileSystemItem = FileSystemItem.fromFileSystemEntity(file);
      ref.read(selectedFileProvider.notifier).state = fileSystemItem;
    } catch (e) {
      // Silently handle errors
    }
  }

  // Method to set the outline refresh callback
  void _setOutlineRefreshCallback(VoidCallback callback) {
    _refreshOutlineCallback = callback;
  }

  // Method to toggle outline panel visibility
  void toggleOutlinePanel() {
    // For now, we'll just show a message since the outline panel
    // is automatically shown/hidden based on file selection
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Outline panel visibility is controlled by file selection',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  // Try to load a project and return success status
  Future<bool> tryLoadProject(String directoryPath) async {
    final projectService = ref.read(projectLoadingServiceProvider);
    return await projectService.tryLoadProject(directoryPath);
  }

  // Method to pick directory - can be called from WelcomeScreen
  Future<void> pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        final projectService = ref.read(projectLoadingServiceProvider);

        // Try to load the project using the service
        final success = await projectService.tryLoadProject(selectedDirectory);
        if (success) {
          // Update MRU and reopen last file
          await projectService.updateMruList(selectedDirectory);
          await projectService.tryReopenLastFile(selectedDirectory);
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

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);
    final projectLoaded = ref.watch(projectLoadedProvider);
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final mruFolders = ref.watch(mruFoldersProvider);

    // Handle file selection changes
    if (selectedFile != null && selectedFile.path != _lastSelectedFilePath) {
      // Save last opened file to SharedPreferences
      _saveLastOpenedFile(selectedFile.path);
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
          // Left Panel
          if (projectLoaded) ...[
            SizedBox(
              width: _explorerWidth,
              child: LeftPanel(
                selectedFile: selectedFile,
                currentProjectPath: currentProjectPath,
                projectLoaded: projectLoaded,
                onFileSelected: (file) {
                  ref.read(selectedFileProvider.notifier).state = file;
                },
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
                  final projectService = ref.read(
                    projectLoadingServiceProvider,
                  );
                  projectService.updateMruList(path);
                  ref.read(currentProjectPathProvider.notifier).state = path;
                },
                showGitPanel: _activeLeftPanel == 1,
                onToggleGitPanel: () {
                  setState(
                    () => _activeLeftPanel = _activeLeftPanel == 0 ? 1 : 0,
                  );
                },
              ),
            ),

            // Resizable Splitter between Left and Center
            ResizableSplitter(onResize: _onResize),
          ],

          // Center Panel
          Expanded(
            child: CenterPanel(
              selectedFile: selectedFile,
              projectLoaded: projectLoaded,
              mruFolders: mruFolders,
              onOpenFolder: pickDirectory,
              onOpenMruProject: (path) async {
                final projectService = ref.read(projectLoadingServiceProvider);
                final success = await projectService.tryLoadProject(path);
                if (success) {
                  await projectService.updateMruList(path);
                  await projectService.tryReopenLastFile(path);
                }
              },
              onRemoveMruEntry: (path) async {
                final updatedMruFolders = List<String>.from(mruFolders)
                  ..remove(path);
                ref.read(mruFoldersProvider.notifier).state = updatedMruFolders;

                // Save to SharedPreferences
                try {
                  final prefs = await ref.read(
                    sharedPreferencesProvider.future,
                  );
                  await prefs.setStringList(_mruFoldersKey, updatedMruFolders);
                } catch (e) {
                  // Silently handle SharedPreferences errors
                }
              },
              onContentChanged: _refreshOutlineCallback,
              onClose: () {
                ref.read(selectedFileProvider.notifier).state = null;
              },
            ),
          ),

          // Right Panel
          if (selectedFile != null) ...[
            // Resizable Splitter between Center and Right
            ResizableSplitter(onResize: _onOutlineResize),
            SizedBox(
              width: _outlineWidth,
              child: RightPanel(
                selectedFile: selectedFile,
                onOutlineUpdate: _setOutlineRefreshCallback,
                onOutlineNodeSelected: (int line, int column) {
                  EditorScreen.navigateToLine(line, column: column);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Save last opened file to SharedPreferences
  Future<void> _saveLastOpenedFile(String filePath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString(_lastOpenedFileKey, filePath);
    } catch (e) {
      // Silently handle SharedPreferences errors
    }
  }
}
