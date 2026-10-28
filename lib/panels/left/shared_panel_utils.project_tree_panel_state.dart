part of 'shared_panel_utils.dart';

/// Behaviour shared by the project tree panels: panel state lifecycle,
/// following the loaded project, file taps, context menus, refresh, and the
/// empty states shown before a tree exists.
mixin ProjectTreePanelState<T extends ProjectTreePanel> on ConsumerState<T> {
  /// Expansion, filter and Git state for this panel.
  late final PanelStateManager panelState = PanelStateManager(
    ref.read(gitServiceProvider),
  );

  /// Create, rename and delete flows for the context menu.
  late final FileOperations _fileOperations = FileOperations(
    ref.read(fileEntryServiceProvider),
  );

  /// Expanded/collapsed state by directory path.
  Map<String, bool> get expandedState => panelState.expandedState;

  /// Root of the tree the panel is showing, if a project is loaded.
  ProjectNode? get projectRoot => panelState.projectRoot;

  /// Renders the tree placeholder shown while the project has no root node.
  Widget buildNoProjectView() {
    return Container(
      color: Theme.of(context).colorScheme.inverseSurface,
      child: const NoProjectPlaceholder(showIcon: true),
    );
  }

  /// Renders the panel-wide placeholder shown when no project is loaded.
  Widget buildNotLoadedView() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: const NoProjectPlaceholder(),
    );
  }

  @override
  void dispose() {
    panelState.dispose();
    super.dispose();
  }

  /// Opens [node] as the selected file, seeding its Git status first.
  void handleFileTap(ProjectNode node) {
    if (widget.selectedFile?.path == node.path) return;

    if (node.gitStatus == GitFileStatus.clean && projectRoot != null) {
      panelState.seedGitStatusForFile(node).then((_) {
        if (mounted) setState(() {});
      });
    }

    widget.onFileSelected?.call(
      FileSystemItem.fromFileSystemEntity(File(node.path)),
    );
  }

  @override
  void initState() {
    super.initState();
    panelState.initialize();
  }

  /// Opens [node] from its context menu: toggles a directory, opens a file.
  void openNode(ProjectNode node) {
    toggleOrOpenNode(node, expandedState[node.path] ?? false);
  }

  /// Called after the tree is replaced or reloaded; panels clear caches
  /// derived from it here.
  void onProjectTreeChanged() {}

  /// Re-enumerates the whole project tree and rebuilds.
  Future<void> refreshProjectTree() async {
    if (projectRoot == null) return;

    try {
      await const ProjectTreeReader().loadTree(projectRoot!);
      onProjectTreeChanged();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showError('Failed to refresh project tree: $e');
    }
  }

  /// Runs the context-menu [action] chosen for [node].
  void runNodeAction(NodeAction action, ProjectNode node) {
    switch (action) {
      case NodeAction.open:
        openNode(node);
      case NodeAction.reveal:
        _reveal(node);
      case NodeAction.copyFullPath:
        _copyPath(node.path, 'Full path copied to clipboard');
      case NodeAction.copyRelativePath:
        if (projectRoot != null) {
          _copyPath(
            path.relative(node.path, from: projectRoot!.path),
            'Relative path copied to clipboard',
          );
        }
      case NodeAction.newFile:
        _fileOperations.createNewFile(context, node, refreshProjectTree);
      case NodeAction.newFolder:
        _fileOperations.createNewFolder(context, node, refreshProjectTree);
      case NodeAction.rename:
        _fileOperations.renameFile(context, node, refreshProjectTree);
      case NodeAction.delete:
        _fileOperations.deleteFile(context, node, refreshProjectTree);
    }
  }

  /// Shows an error message with a copy button.
  void showError(String message) {
    MessageBox.showError(context, message);
  }

  /// Shows the file/folder context menu for [node] at [position].
  void showNodeContextMenu(ProjectNode node, Offset position) {
    ContextMenuHandler.showNodeContextMenu(
      context,
      node,
      position,
      runNodeAction,
    );
  }

  /// Copies [text] to the clipboard and confirms with a snack bar.
  void _copyPath(String text, String confirmation) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  /// Shows [node]'s folder (or the folder holding it) in the file manager.
  Future<void> _reveal(ProjectNode node) async {
    try {
      await ref
          .read(processRunnerProvider)
          .revealInFileManager(
            node.isDirectory ? node.path : path.dirname(node.path),
          );
    } catch (e) {
      showError('Failed to reveal ${node.name}: $e');
    }
  }

  /// Collapses or expands a directory (loading its children on first
  /// expand), or opens a file.
  Future<void> toggleOrOpenNode(ProjectNode node, bool isExpanded) async {
    if (!node.isDirectory) {
      handleFileTap(node);
      return;
    }

    setState(() => expandedState[node.path] = !isExpanded);
    if (isExpanded) return;

    final result = await panelState.ensureDirectoryLoaded(node);
    if (!mounted) return;
    switch (result) {
      case LoadChildrenResult.success:
        setState(() {});
      case LoadChildrenResult.accessDenied:
        showError('Access denied: ${node.name}');
      case LoadChildrenResult.fileSystemError ||
          LoadChildrenResult.unknownError:
        showError('Failed to load directory: ${node.name}');
    }
  }

  /// Adopts [root] when the loaded project changes. Call it from `build`
  /// before reading the tree; it mutates state without `setState` because
  /// the build in progress already uses the new values.
  void syncProjectRoot(ProjectNode? root) {
    if (root == panelState.projectRoot) return;
    panelState.projectRoot = root;
    panelState.expandedState.clear();
    onProjectTreeChanged();
  }
}
