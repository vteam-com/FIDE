part of 'main_layout.dart';

/// Represents `MainLayoutState`.
class MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = AppSize.initialSidePanelWidth;
  double _outlineWidth = AppSize.initialSidePanelWidth;

  /// Widths the side panels had in the last layout, expanded or not.
  double _shownExplorerWidth = AppSize.initialSidePanelWidth;
  double _shownOutlineWidth = AppSize.initialSidePanelWidth;

  String? _lastSelectedFilePath;

  @override
  void initState() {
    super.initState();
    // The layout mounts once a project has loaded; restore its last file now
    // that the selection listener in build is about to be registered
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      ref.read(lastOpenedFileProvider.notifier).tryReopen(projectPath);
    }
  }

  /// Resizes the left panel as its splitter moves [delta] right.
  void _onResize(double delta) {
    setState(() {
      _explorerWidth = _dragged(
        _explorerWidth,
        _shownExplorerWidth,
        leftPanelExpandedProvider,
        delta,
      );
    });
  }

  /// Resizes the right panel as its splitter moves [delta] right.
  void _onOutlineResize(double delta) {
    setState(() {
      _outlineWidth = _dragged(
        _outlineWidth,
        _shownOutlineWidth,
        rightPanelExpandedProvider,
        -delta,
      );
    });
  }

  /// A side panel's [width] after its splitter moves [delta] wider; an
  /// [expanded] panel, [shownWidth] wide, stops being expanded and grows
  /// from that width.
  double _dragged(
    double width,
    double shownWidth,
    StateProvider<bool> expanded,
    double delta,
  ) {
    var start = width;
    if (ref.read(expanded)) {
      ref.read(expanded.notifier).state = false;
      start = shownWidth;
    }
    return (start + delta).clamp(
      AppSize.minSidePanelWidth,
      AppSize.maxSidePanelWidth,
    );
  }

  /// Lays out the side panels in [availableWidth]: expanded ones share
  /// what the others leave, keeping [AppSize.editorMinWidth] for the
  /// editor, up to [AppSize.maxSidePanelWidth] each. A hidden panel is
  /// neither shown nor expanded.
  void _fitSidePanels(
    double availableWidth, {
    required bool leftShown,
    required bool rightShown,
    required bool leftExpanded,
    required bool rightExpanded,
  }) {
    final fixedWidth =
        (leftShown && !leftExpanded ? _explorerWidth : 0) +
        (rightShown && !rightExpanded ? _outlineWidth : 0);
    final expandedCount = (leftExpanded ? 1 : 0) + (rightExpanded ? 1 : 0);
    final expandedWidth = expandedCount == 0
        ? 0.0
        : ((availableWidth - AppSize.editorMinWidth - fixedWidth) /
                  expandedCount)
              .clamp(AppSize.minSidePanelWidth, AppSize.maxSidePanelWidth);
    _shownExplorerWidth = leftExpanded ? expandedWidth : _explorerWidth;
    _shownOutlineWidth = rightExpanded ? expandedWidth : _outlineWidth;
  }

  @override
  Widget build(BuildContext context) {
    final projectLoaded = ref.watch(projectLoadedProvider);

    ref.listen<FileSystemItem?>(selectedFileProvider, (_, next) {
      if (next != null && next.path != _lastSelectedFilePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _handleFileSelection(next);
        });
      }
    });

    // Switching editor tabs selects the tab's file, so the tree and the
    // Outline follow it
    ref.listen(activeDocumentProvider.select((doc) => doc?.filePath), (
      _,
      path,
    ) {
      if (path != null && path != ref.read(selectedFileProvider)?.path) {
        openFile(ref, path);
      }
    });

    final leftShown = projectLoaded && ref.watch(leftPanelVisibleProvider);
    final rightShown = ref.watch(rightPanelVisibleProvider);
    final leftExpanded = leftShown && ref.watch(leftPanelExpandedProvider);
    final rightExpanded = rightShown && ref.watch(rightPanelExpandedProvider);

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
        child: LayoutBuilder(
          builder: (_ /*context*/, constraints) {
            _fitSidePanels(
              constraints.maxWidth,
              leftShown: leftShown,
              rightShown: rightShown,
              leftExpanded: leftExpanded,
              rightExpanded: rightExpanded,
            );
            return Row(
              children: [
                if (leftShown) ...[
                  SizedBox(
                    width: _shownExplorerWidth,
                    child: const PanelIsland(child: LeftPanel()),
                  ),
                  ResizableSplitter(onResize: _onResize),
                ],
                Expanded(
                  child: CenterPanel(
                    terminalVisible: ref.watch(bottomPanelVisibleProvider),
                    onClose: _closeActiveDocument,
                  ),
                ),
                if (rightShown) ...[
                  ResizableSplitter(onResize: _onOutlineResize),
                  SizedBox(
                    width: _shownOutlineWidth,
                    child: const PanelIsland(child: RightPanel()),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Closes the showing document; the next tab's file becomes the
  /// selected one, or none when no tab is left.
  Future<void> _closeActiveDocument() async {
    final documents = ref.read(openDocumentsProvider.notifier);
    await documents.closeActive();
    if (!mounted || ref.read(activeDocumentProvider) != null) return;
    ref.read(selectedFileProvider.notifier).state = null;
    // Selecting the closed file again must reopen it
    _lastSelectedFilePath = null;
  }

  Future<void> _handleFileSelection(FileSystemItem file) async {
    await ref.read(lastOpenedFileProvider.notifier).save(file.path);
    await ref.read(openDocumentsProvider.notifier).open(file.path);

    ref.read(rightPanelVisibleProvider.notifier).state = true;
    _lastSelectedFilePath = file.path;
  }
}
