part of 'main_layout.dart';

/// Represents `MainLayoutState`.
class MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = AppSize.initialSidePanelWidth;
  double _outlineWidth = AppSize.initialSidePanelWidth;
  final double _minExplorerWidth = 150.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 500.0;

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

  /// Opens [filePath] in the editor and scrolls to 1-based [line].
  Future<void> _jumpToLine(String filePath, int line) =>
      openFileAtLine(ref, filePath, line);

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

    // Panels float as islands on the window-wide workspace gradient; the
    // splitters between them double as the gaps
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSize.islandGap,
          0,
          AppSize.islandGap,
          AppSize.islandGap,
        ),
        child: Row(
          children: [
            if (projectLoaded && ref.watch(leftPanelVisibleProvider)) ...[
              SizedBox(
                width: _explorerWidth,
                child: PanelIsland(
                  child: LeftPanel(
                    selectedFile: selectedFile,
                    currentProjectPath: currentProjectPath,
                    projectLoaded: projectLoaded,
                    onFileSelected: (file) {
                      ref.read(selectedFileProvider.notifier).state = file;
                    },
                    onJumpToLine: _jumpToLine,
                  ),
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
                  ref.read(openDocumentsProvider.notifier).deactivate();
                },
              ),
            ),
            if (ref.watch(rightPanelVisibleProvider)) ...[
              ResizableSplitter(onResize: _onOutlineResize),
              SizedBox(
                width: _outlineWidth,
                child: PanelIsland(
                  child: RightPanel(
                    selectedFile: selectedFile,
                    onOutlineUpdate: _setOutlineRefreshCallback,
                    onJumpToLine: _jumpToLine,
                    onOutlineNodeSelected: (int line, int column) {
                      ref
                          .read(activeEditorProvider)
                          .navigateToLine(line, column: column);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileSelection(FileSystemItem file) async {
    await ref.read(projectManagerProvider).saveLastOpenedFile(file.path);
    await ref.read(openDocumentsProvider.notifier).open(file.path);

    final fileName = path.basename(file.path);
    widget.onFileOpened?.call(fileName);

    ref.read(rightPanelVisibleProvider.notifier).state = true;
    _lastSelectedFilePath = file.path;
  }
}
