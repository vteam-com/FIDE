part of 'shared_panel_utils.dart';

/// Behaviour shared by the project tree panels (Folder and Organized):
/// the tree's expansion state, following the loaded project, file taps,
/// context menus and refresh. The panel's `build` returns
/// [buildPanelContent], which shows [buildProjectTree] once a project is
/// loaded.
mixin ProjectTreePanelState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Expanded/collapsed state by directory path, or by section key.
  final Map<String, bool> expandedState = {};

  /// Root of the tree the panel is showing, if a project is loaded.
  ProjectNode? projectRoot;

  /// Create, rename and delete flows for the context menu.
  late final FileOperations _fileOperations = FileOperations(
    ref.read(fileEntryServiceProvider),
    (from, to, {required isDirectory}) =>
        renameInProject(ref, from, to, isDirectory: isDirectory),
  );

  /// Follows the loaded project, rebuilding when its tree changes in
  /// place (e.g. Git status arriving), and shows [buildProjectTree] once
  /// there is one, the placeholder until then. Call it from `build`.
  Widget buildPanelContent() {
    final root = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);
    ref.watch(projectTreeRevisionProvider);
    syncProjectRoot(root);
    return !isProjectLoaded || root == null
        ? const NoProjectPlaceholder()
        : buildProjectTree(root);
  }

  /// The panel's tree of [root], the loaded project.
  Widget buildProjectTree(ProjectNode root);

  /// Loads [node]'s children if it is a directory that hasn't been loaded.
  Future<LoadChildrenResult> ensureDirectoryLoaded(ProjectNode node) async {
    if (!node.isDirectory || node.children.isNotEmpty) {
      return LoadChildrenResult.success;
    }
    return ref.read(projectTreeReaderProvider).loadChildren(node);
  }

  /// Opens [node] as the selected file, seeding its Git status first; the
  /// selected file, clicked again, folds or unfolds its outline instead.
  void handleFileTap(ProjectNode node) {
    if (ref.read(selectedFileProvider)?.path == node.path) {
      final folded = ref.read(foldedOutlinePathProvider.notifier);
      folded.state = folded.state == node.path ? null : node.path;
      return;
    }

    final root = projectRoot;
    if (node.gitStatus == GitFileStatus.clean && root != null) {
      // The status the Git badge already loaded; no Git process per tap
      final status = ref.read(gitRepoControllerProvider(root.path)).value;
      setState(() => _seedGitStatusForFile(node, root, status?.status));
    }

    openItem(ref, FileSystemItem.fromNode(node));
  }

  /// Called after the tree is replaced or reloaded; panels clear caches
  /// derived from it here.
  void onProjectTreeChanged() {}

  /// Re-enumerates the whole project tree and rebuilds.
  Future<void> refreshProjectTree() async {
    final root = projectRoot;
    if (root == null) return;

    try {
      await ref.read(projectTreeReaderProvider).loadTree(root);
      if (!mounted) return;
      ref.read(projectTreeRevisionProvider.notifier).state++;
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

  /// Shows the file/folder context menu for [node] at [position]: the
  /// [FileAction]s that apply to it, then the [NodeAction]s.
  void showNodeContextMenu(ProjectNode node, Offset position) {
    final shell = ref.read(desktopShellProvider);
    final projectPath = projectRoot?.path;
    showActionMenu(context, position, [
      for (final action in FileAction.values)
        if (action.inProjectTrees &&
            action.appliesTo(
              node.path,
              isDirectory: node.isDirectory,
              projectPath: projectPath,
            ))
          IconMenuItem(
            value: () => action.run(
              context,
              ref,
              node.path,
              isDirectory: node.isDirectory,
            ),
            icon: action.icon,
            label: action.labelIn(shell),
          ),
      for (final action in NodeAction.values)
        if (action.appliesTo(node))
          IconMenuItem(
            value: () => runNodeAction(action, node),
            icon: action.icon,
            label: action.label,
            isError: action.isDestructive,
          ),
    ]);
  }

  /// Tags [node], under [root], with its change in [status], the
  /// project's Git status; leaves it as is while the status is unknown.
  static void _seedGitStatusForFile(
    ProjectNode node,
    ProjectNode root,
    GitStatus? status,
  ) {
    if (status == null) return;
    node.gitStatus = status.statusOf(p.relative(node.path, from: root.path));
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

    final result = await ensureDirectoryLoaded(node);
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
    if (root == projectRoot) return;
    projectRoot = root;
    expandedState.clear();
    onProjectTreeChanged();
  }
}
