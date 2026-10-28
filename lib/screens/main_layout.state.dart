part of 'main_layout.dart';

/// Represents `MainLayoutState`.
class MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = AppSize.initialSidePanelWidth;
  double _outlineWidth = AppSize.initialSidePanelWidth;
  final double _minExplorerWidth = 150.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 500.0;

  int _activeLeftPanel = 0;
  VoidCallback? _refreshOutlineCallback;

  String? _lastSelectedFilePath;

  @override
  void initState() {
    super.initState();
    // The layout mounts once a project has loaded; restore its last file now
    // that the selection listener in build is about to be registered
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      ref.read(projectManagerProvider).tryReopenLastFile(projectPath);
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
                  ref.read(activeEditorProvider).navigateToLine(line);
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
              onOpenFolder: widget.onOpenFolder,
              onOpenMruProject: widget.onOpenProject,
              onRemoveMruEntry: ref.read(mruFoldersProvider.notifier).remove,
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
                  ref
                      .read(activeEditorProvider)
                      .navigateToLine(line, column: column);
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
      final language = FileTypeUtils.languageForFile(filePath);
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

  Future<void> _handleFileSelection(FileSystemItem file) async {
    await ref.read(projectManagerProvider).saveLastOpenedFile(file.path);
    await _addFileToOpenDocuments(file.path);

    final fileName = path.basename(file.path);
    widget.onFileOpened?.call(fileName);

    ref.read(rightPanelVisibleProvider.notifier).state = true;
    _lastSelectedFilePath = file.path;
  }
}
