part of 'shared_panel_utils.dart';

/// Behaviour shared by the project tree panels: panel state lifecycle,
/// following the loaded project, file taps, context menus, refresh, and the
/// empty states shown before a tree exists.
mixin ProjectTreePanelState<T extends ProjectTreePanel> on ConsumerState<T> {
  /// Expansion, filter and Git state for this panel.
  late final PanelStateManager panelState = PanelStateManager(
    ref.read(gitServiceProvider),
  );

  /// Expanded/collapsed state by directory path.
  Map<String, bool> get expandedState => panelState.expandedState;

  /// Root of the tree the panel is showing, if a project is loaded.
  ProjectNode? get projectRoot => panelState.projectRoot;

  /// Renders the tree placeholder shown while the project has no root node.
  Widget buildNoProjectView() {
    return Container(
      color: Theme.of(context).colorScheme.inverseSurface,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: AppIconSize.emptyState,
              color: Colors.grey,
            ),
            SizedBox(height: AppSpacing.xLarge),
            Text('No project loaded'),
          ],
        ),
      ),
    );
  }

  /// Renders the panel-wide placeholder shown when no project is loaded.
  Widget buildNotLoadedView() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: Text(
          'No project loaded',
          style: TextStyle(fontSize: AppFontSize.title),
        ),
      ),
    );
  }

  @override
  void dispose() {
    panelState.dispose();
    super.dispose();
  }

  /// Handles a context-menu [action] chosen for [node].
  void handleContextMenuAction(String action, ProjectNode node) {
    if (action == 'open') {
      openNode(node);
    } else {
      runNodeAction(action, node);
    }
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
      await projectRoot!.enumerateContentsRecursive();
      onProjectTreeChanged();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showError('Failed to refresh project tree: $e');
    }
  }

  /// Runs a file-management context-menu [action] on [node]: reveal, copy
  /// path, create, rename or delete. Unknown actions are ignored.
  void runNodeAction(String action, ProjectNode node) {
    switch (action) {
      case 'reveal':
        FileOperations.revealInFileExplorer(node);
      case 'copy_full_path':
        _copyPath(node.path, 'Full path copied to clipboard');
      case 'copy_relative_path':
        if (projectRoot != null) {
          _copyPath(
            path.relative(node.path, from: projectRoot!.path),
            'Relative path copied to clipboard',
          );
        }
      case 'new_file':
        FileOperations.createNewFile(context, node, refreshProjectTree);
      case 'new_folder':
        FileOperations.createNewFolder(context, node, refreshProjectTree);
      case 'rename':
        FileOperations.renameFile(context, node, refreshProjectTree);
      case 'delete':
        FileOperations.deleteFile(context, node, refreshProjectTree);
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
      handleContextMenuAction,
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
