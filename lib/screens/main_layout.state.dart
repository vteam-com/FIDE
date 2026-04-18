part of 'main_layout.dart';

/// Represents `MainLayoutState`.
class MainLayoutState extends ConsumerState<MainLayout> {
  final Logger _logger = Logger('MainLayoutState');

  double _explorerWidth = AppSize.initialSidePanelWidth;
  double _outlineWidth = AppSize.initialSidePanelWidth;
  final double _minExplorerWidth = 150.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 500.0;

  int _activeLeftPanel = 0;
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
    await _loadMruFoldersIntoProvider();
  }

  /// Loads persisted MRU folders into state and auto-opens the most recent valid project.
  Future<void> _loadMruFoldersIntoProvider() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final mruList = prefs.getStringList(_mruFoldersKey) ?? [];

      final validMruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();

      ref.read(mruFoldersProvider.notifier).state = validMruFolders;

      if (validMruFolders.isNotEmpty) {
        await _tryAutoLoadProject(validMruFolders.first);
      }
    } catch (_) {
      // Silently handle errors during initialization.
    }
  }

  /// Validates and auto-loads a recent Flutter project, then reopens its last file.
  Future<void> _tryAutoLoadProject(String directoryPath) async {
    try {
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

      ref.read(currentProjectPathProvider.notifier).state = directoryPath;
      ref.read(projectLoadedProvider.notifier).state = true;

      await tryReopenLastFile(directoryPath);
    } catch (e) {
      _logger.warning('Failed to auto-load MRU project: $e');
    }
  }

  /// Reopens the last persisted file for the given project, when valid.
  Future<void> tryReopenLastFile(String projectPath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastFilePath = prefs.getString(_lastOpenedFileKey);

      if (lastFilePath == null || lastFilePath.isEmpty) {
        return;
      }

      final file = File(lastFilePath);
      if (!await file.exists()) {
        return;
      }

      if (!path.isWithin(projectPath, lastFilePath)) {
        return;
      }

      if (!FileTypeUtils.isFileSupportedInEditor(lastFilePath)) {
        return;
      }

      if (!await FileSystemItem.isWithinMaxFileSize(file)) {
        return;
      }

      final fileSystemItem = FileSystemItem.forMruLoading(lastFilePath);
      ref.read(selectedFileProvider.notifier).state = fileSystemItem;
    } catch (_) {
      // Silently handle errors.
    }
  }

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

  /// Loads a project through [ProjectManager] and returns whether it succeeded.
  Future<bool> tryLoadProject(String directoryPath) async {
    final projectManager = ref.read(projectManagerProvider);
    return await projectManager.loadProject(directoryPath);
  }

  /// Opens a folder picker and attempts to load the selected Flutter project.
  Future<void> pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (!mounted) return;

      if (selectedDirectory != null) {
        final projectManager = ref.read(projectManagerProvider);
        final success = await projectManager.loadProject(selectedDirectory);
        if (!mounted) return;

        if (success) {
          await projectManager.tryReopenLastFile(selectedDirectory);
        } else {
          MessageBox.showError(
            context,
            'Selected folder is not a valid Flutter project',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      MessageBox.showError(context, 'Error loading project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);
    final projectLoaded = ref.watch(projectLoadedProvider);
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final mruFolders = ref.watch(mruFoldersProvider);

    ref.listen<FileSystemItem?>(selectedFileProvider, (_, next) {
      if (next != null && next.path != _lastSelectedFilePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _handleFileSelection(next);
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      body: Row(
        children: [
          if (projectLoaded && ref.watch(leftPanelVisibleProvider)) ...[
            SizedBox(
              width: _explorerWidth,
              child: LeftPanel(
                selectedFile: selectedFile,
                currentProjectPath: currentProjectPath,
                projectLoaded: projectLoaded,
                onFileSelected: (file) {
                  ref.read(selectedFileProvider.notifier).state = file;
                },
                onJumpToLine: (filePath, line) async {
                  final file = File(filePath);
                  final fileSystemItem = FileSystemItem.fromFileSystemEntity(
                    file,
                  );
                  ref.read(selectedFileProvider.notifier).state =
                      fileSystemItem;

                  await Future.delayed(AppDuration.editorScroll);
                  EditorScreen.navigateToLine(line);
                },
                onThemeChanged: (themeMode) {
                  ref.read(themeModeProvider.notifier).state = themeMode;
                },
                onProjectLoaded: (loaded) {
                  ref.read(projectLoadedProvider.notifier).state = loaded;
                  if (!loaded) {
                    ref.read(currentProjectPathProvider.notifier).state = null;
                    ref.read(selectedFileProvider.notifier).state = null;
                  }
                },
                onProjectPathChanged: (path) {
                  final projectManager = ref.read(projectManagerProvider);
                  projectManager.loadProject(path);
                  ref.read(currentProjectPathProvider.notifier).state = path;
                },
                onToggleGitPanel: () {
                  setState(
                    () => _activeLeftPanel = _activeLeftPanel == 0 ? 1 : 0,
                  );
                },
              ),
            ),
            ResizableSplitter(onResize: _onResize),
          ],
          Expanded(
            child: CenterPanel(
              selectedFile: selectedFile,
              projectLoaded: projectLoaded,
              mruFolders: mruFolders,
              terminalVisible: ref.watch(bottomPanelVisibleProvider),
              onOpenFolder: pickDirectory,
              onOpenMruProject: (path) async {
                final mainLayoutState = context
                    .findAncestorStateOfType<MainLayoutState>();
                if (mainLayoutState != null) {
                  await mainLayoutState.tryLoadProject(path);
                } else {
                  final projectManager = ref.read(projectManagerProvider);
                  final success = await projectManager.loadProject(path);
                  if (success) {
                    await projectManager.tryReopenLastFile(path);
                  }
                }
              },
              onRemoveMruEntry: (path) async {
                final updatedMruFolders = List<String>.from(mruFolders)
                  ..remove(path);
                ref.read(mruFoldersProvider.notifier).state = updatedMruFolders;

                try {
                  final prefs = await ref.read(
                    sharedPreferencesProvider.future,
                  );
                  await prefs.setStringList(_mruFoldersKey, updatedMruFolders);
                } catch (_) {
                  // Silently handle SharedPreferences errors.
                }
              },
              onContentChanged: _refreshOutlineCallback,
              onClose: () {
                ref.read(selectedFileProvider.notifier).state = null;
                ref.read(activeDocumentIndexProvider.notifier).state = -1;
              },
            ),
          ),
          if (ref.watch(rightPanelVisibleProvider)) ...[
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

  /// Opens a file as a document tab and activates it if it is already open.
  Future<void> _addFileToOpenDocuments(String filePath) async {
    final openDocuments = ref.read(openDocumentsProvider);
    final existingIndex = openDocuments.indexWhere(
      (doc) => doc.filePath == filePath,
    );

    if (existingIndex == -1) {
      final Mode language = _getLanguageForFile(filePath);
      String content = '';
      bool isImage = FileTypeUtils.isImageFile(filePath);

      if (!isImage) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            content = await FileSystemItem.fileToStringMaxSizeCheck(file);
          }
        } catch (_) {
          content = '// Error loading file\n';
        }
      }

      final newDocument = DocumentState(
        filePath: filePath,
        content: content,
        language: language,
      );

      final updatedDocuments = [...openDocuments, newDocument];
      ref.read(openDocumentsProvider.notifier).state = updatedDocuments;
      ref.read(activeDocumentIndexProvider.notifier).state =
          updatedDocuments.length - 1;
    } else {
      ref.read(activeDocumentIndexProvider.notifier).state = existingIndex;
    }
  }

  /// Maps a file path to the syntax highlighter language used by the editor.
  Mode _getLanguageForFile(String filePath) {
    if (filePath.isEmpty) {
      return plaintext;
    }
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return dart;
      case 'yaml':
      case 'yml':
        return yaml;
      case 'arb':
      case 'json':
        return json;
      case 'js':
        return javascript;
      default:
        return plaintext;
    }
  }

  Future<void> _handleFileSelection(FileSystemItem file) async {
    await _saveLastOpenedFile(file.path);
    await _addFileToOpenDocuments(file.path);

    final fileName = path.basename(file.path);
    widget.onFileOpened?.call(fileName);

    ref.read(rightPanelVisibleProvider.notifier).state = true;
    _lastSelectedFilePath = file.path;
  }

  Future<void> _saveLastOpenedFile(String filePath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString(_lastOpenedFileKey, filePath);
    } catch (_) {
      // Silently handle SharedPreferences errors.
    }
  }
}
