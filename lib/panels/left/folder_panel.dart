// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/utils/message_helper.dart';

import 'package:fide/panels/left/git_panel.dart';
import 'package:fide/theme/app_theme.dart';

// Widgets
import 'left_panel.dart';

// Providers
import '../../providers/app_providers.dart';

class FolderPanel extends ConsumerStatefulWidget {
  const FolderPanel({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.initialProjectPath,
    this.showGitPanel = false,
    this.onToggleGitPanel,
    required this.panelMode,
  });

  final String? initialProjectPath;

  final Function(FileSystemItem)? onFileSelected;

  final Function(bool)? onProjectLoaded;

  final Function(String)? onProjectPathChanged;

  final Function(ThemeMode)? onThemeChanged;

  final VoidCallback? onToggleGitPanel;

  final FileSystemItem? selectedFile;

  final bool showGitPanel;

  final PanelMode panelMode;

  @override
  ConsumerState<FolderPanel> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<FolderPanel> {
  final Map<String, bool> _expandedState = {};

  final GitService _gitService = GitService();

  bool _isLoading = false;

  final Set<String> _loadingDirectories = {};

  PanelMode _panelMode = PanelMode.filesystem;

  ProjectNode? _projectRoot;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeExplorer();
  }

  @override
  void dispose() {
    // Cancel any pending operations
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FolderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selectedFile changed, expand the tree to show it
    if (widget.selectedFile != oldWidget.selectedFile &&
        widget.selectedFile != null &&
        _projectRoot != null) {
      _expandToFile(widget.selectedFile!.path);
    } else if (widget.selectedFile != oldWidget.selectedFile) {
      // Force a rebuild to update selection highlighting even if project isn't loaded yet
      setState(() {});
    }

    // If panel mode changed, update local state
    if (widget.panelMode != oldWidget.panelMode) {
      setState(() {
        _panelMode = widget.panelMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project path changes and reload project if needed
    final currentProjectPath = ref.watch(currentProjectPathProvider);

    // If project path changed and we have a different project loaded, reload it
    if (currentProjectPath != null &&
        _projectRoot != null &&
        currentProjectPath != _projectRoot!.path &&
        !_isLoading) {
      // Use a microtask to avoid calling setState during build
      Future.microtask(() async {
        if (mounted) {
          await _loadProject(currentProjectPath, forceLoad: true);
        }
      });
    }

    // Ensure selected file is expanded and visible when building
    if (widget.selectedFile != null && _projectRoot != null && !_isLoading) {
      // Use a microtask to ensure this happens after the current build cycle
      Future.microtask(() {
        if (mounted) {
          _expandToFile(widget.selectedFile!.path);
        }
      });
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _projectRoot == null
        ? Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(
              child: Text('No project loaded', style: TextStyle(fontSize: 16)),
            ),
          )
        : widget.showGitPanel
        ? _buildGitPanel()
        : _buildFileExplorer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also check for selected file when dependencies change
    if (widget.selectedFile != null && _projectRoot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _expandToFile(widget.selectedFile!.path);
      });
    }
  }

  Widget _buildCategorySection(String category, List<ProjectNode> nodes) {
    final isExpanded = _expandedState['category_$category'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        InkWell(
          onTap: () {
            if (mounted) {
              setState(() {
                _expandedState['category_$category'] = !isExpanded;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: AppTheme.sidePanelSurface(context),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${nodes.length})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category content
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes.map((node) => _buildNode(node)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDirectoryNode(ProjectNode node) {
    final isExpanded = _expandedState[node.path] ?? false;
    final hasError =
        node.loadResult != null &&
        node.loadResult != LoadChildrenResult.success;

    // Determine text color based on hidden status and error status
    Color textColor;
    if (hasError) {
      textColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine icon color
    Color iconColor;
    if (hasError) {
      iconColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      iconColor = Theme.of(context).colorScheme.primary.withOpacity(0.5);
    } else {
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _onNodeTapped(node, isExpanded),
          onLongPress: () => _showNodeContextMenu(node),
          hoverColor: Colors.blue.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  hasError ? Icons.folder_off : Icons.folder,
                  color: iconColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(fontSize: 13, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(width: 4),
                  Icon(
                    node.loadResult == LoadChildrenResult.accessDenied
                        ? Icons.lock
                        : Icons.error,
                    color: Theme.of(context).colorScheme.error,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (node.isDirectory && isExpanded)
          Padding(
            padding: EdgeInsets.only(left: node.children.isEmpty ? 32 : 16.0),
            child: node.children.isEmpty
                ? const Text(
                    'empty folder',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  )
                : _buildNodeChildren(node),
          ),
      ],
    );
  }

  Widget _buildFileExplorer() {
    if (_projectRoot == null) {
      return Container(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No project loaded'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Project'),
              ),
            ],
          ),
        ),
      );
    }

    if (_panelMode == PanelMode.organized) {
      return _buildOrganizedView();
    }

    return SingleChildScrollView(
      child: Column(
        children: _projectRoot!.children
            .map((node) => _buildNode(node))
            .toList(),
      ),
    );
  }

  Widget _buildFileNode(ProjectNode node) {
    // More robust path comparison using path normalization
    final isSelected =
        widget.selectedFile != null &&
        (widget.selectedFile!.path == node.path ||
            path.normalize(widget.selectedFile!.path) ==
                path.normalize(node.path) ||
            path.canonicalize(widget.selectedFile!.path) ==
                path.canonicalize(node.path));

    // Get Git status styling
    final gitTextStyle = node.getGitStatusTextStyle(context);
    final badgeText = node.getGitStatusBadge();

    // Determine text color based on selection, hidden status, and Git status
    Color textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = gitTextStyle.color ?? Theme.of(context).colorScheme.onSurface;
    }

    // Determine background color for selection
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primaryContainer.withOpacity(0.3);
    }

    return InkWell(
      onTap: () => _handleFileTap(node),
      onLongPress: () => _showNodeContextMenu(node),
      hoverColor: Colors.blue.withOpacity(0.1),
      child: Container(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            children: [
              _getFileIcon(node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: gitTextStyle.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Git status indicator
              if (badgeText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: node.getGitStatusColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: node.getGitStatusColor(context),
                    ),
                  ),
                ),
              // Context menu button for selected files
              if (isSelected) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTapDown: (details) =>
                      _showFileContextMenu(node, details.globalPosition),
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.more_vert,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGitPanel() {
    if (_projectRoot == null) {
      return const Center(child: Text('No project loaded'));
    }

    return SizedBox.expand(child: GitPanel(projectPath: _projectRoot!.path));
  }

  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return _buildDirectoryNode(node);
    } else {
      return _buildFileNode(node);
    }
  }

  Widget _buildNodeChildren(ProjectNode node) {
    // Deduplicate children by path to prevent duplicate entries
    final uniqueChildren = <String, ProjectNode>{};
    for (final child in node.children) {
      uniqueChildren[child.path] = child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: uniqueChildren.values
          .map((child) => _buildNode(child))
          .toList(),
    );
  }

  Widget _buildOrganizedView() {
    if (_projectRoot == null) return const SizedBox();

    // Group files and directories by categories
    final Map<String, List<ProjectNode>> categories = {
      'Root': [],
      'Lib': [],
      'Tests': [],
      'Assets': [],
      'Platforms': [],
      'Output': [],
    };

    // Find lib, test, and assets directories
    ProjectNode? libDir;
    ProjectNode? testDir;
    ProjectNode? assetsDir;

    for (final node in _projectRoot!.children) {
      if (node.name == 'lib' && node.isDirectory) {
        libDir = node;
      } else if (node.name == 'test' && node.isDirectory) {
        testDir = node;
      } else if (node.name == 'assets' && node.isDirectory) {
        assetsDir = node;
      }
    }

    // Ensure lib directory contents are loaded
    if (libDir != null) {
      _ensureDirectoryLoaded(libDir);
      if (libDir.children.isNotEmpty) {
        categories['Lib']!.addAll(libDir.children);
      }
    }

    // Ensure test directory contents are loaded
    if (testDir != null) {
      _ensureDirectoryLoaded(testDir);
      if (testDir.children.isNotEmpty) {
        categories['Tests']!.addAll(testDir.children);
      }
    }

    // Ensure assets directory contents are loaded
    if (assetsDir != null) {
      _ensureDirectoryLoaded(assetsDir);
      if (assetsDir.children.isNotEmpty) {
        categories['Assets']!.addAll(assetsDir.children);
      }
    }

    // Categorize remaining nodes
    for (final node in _projectRoot!.children) {
      if (node == libDir || node == testDir || node == assetsDir) {
        // Skip lib, test, and assets directories as we already processed their contents
        continue;
      }

      if (node.name == 'android' ||
          node.name == 'ios' ||
          node.name == 'web' ||
          node.name == 'windows' ||
          node.name == 'macos' ||
          node.name == 'linux') {
        categories['Platforms']!.add(node);
      } else if (node.name == 'build' ||
          node.name == '.dart_tool' ||
          node.name == 'benchmark') {
        categories['Output']!.add(node);
      } else {
        categories['Root']!.add(node);
      }
    }

    // Deduplicate categories
    for (final category in categories.keys) {
      final uniqueNodes = <String, ProjectNode>{};
      for (final node in categories[category]!) {
        uniqueNodes[node.path] = node;
      }
      categories[category] = uniqueNodes.values.toList();
    }

    // Build the organized view
    final List<Widget> sections = [];

    for (final category in [
      'Root',
      'Lib',
      'Tests',
      'Assets',
      'Platforms',
      'Output',
    ]) {
      final nodes = categories[category]!;
      if (nodes.isNotEmpty) {
        sections.add(_buildCategorySection(category, nodes));
      }
    }

    return SingleChildScrollView(child: Column(children: sections));
  }

  void _createNewFile(ProjectNode parent) {}

  void _createNewFolder(ProjectNode parent) {}

  Future<void> _deleteFile(ProjectNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete "${node.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Perform the delete operation
      if (node.isDirectory) {
        await Directory(node.path).delete(recursive: true);
      } else {
        await File(node.path).delete();
      }

      // Update the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${node.name}"')));
      }
    } catch (e) {
      _showError('Failed to delete file: $e');
    }
  }

  void _deleteNode(ProjectNode node) {}

  Future<void> _ensureDirectoryLoaded(ProjectNode node) async {
    if (node.children.isEmpty && node.isDirectory) {
      // Mark this directory as loading
      _loadingDirectories.add(node.path);

      try {
        await node.loadChildren();

        // Trigger rebuild when loading is complete
        if (mounted) {
          setState(() {
            _loadingDirectories.remove(node.path);
          });
        }
      } catch (e) {
        // Silently handle errors for organized view - don't show error messages
        // The directory will just appear empty in the organized view
        debugPrint(
          'Failed to load directory ${node.name} for organized view: $e',
        );

        // Remove from loading set even on error
        if (mounted) {
          setState(() {
            _loadingDirectories.remove(node.path);
          });
        }
      }
    }
  }

  void _ensureSelectedFileVisible(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // For organized view, just expand the relevant category
    if (_panelMode == PanelMode.organized) {
      final relativePath = path.relative(filePath, from: _projectRoot!.path);
      String targetCategory = 'Root';

      if (relativePath.startsWith('lib/')) {
        targetCategory = 'Lib';
      } else if (relativePath.startsWith('test/')) {
        targetCategory = 'Tests';
      } else if (relativePath.startsWith('assets/')) {
        targetCategory = 'Assets';
      } else if (relativePath.startsWith('android/') ||
          relativePath.startsWith('ios/') ||
          relativePath.startsWith('web/') ||
          relativePath.startsWith('windows/') ||
          relativePath.startsWith('macos/') ||
          relativePath.startsWith('linux/')) {
        targetCategory = 'Platforms';
      } else if (relativePath.startsWith('build/') ||
          relativePath.startsWith('.dart_tool/') ||
          relativePath.startsWith('benchmark/')) {
        targetCategory = 'Output';
      }

      if (mounted) {
        setState(() {
          _expandedState['category_$targetCategory'] = true;
        });
      }
    } else {
      // For filesystem view, expand the directory containing the file
      final fileDir = path.dirname(filePath);
      if (fileDir != _projectRoot!.path) {
        final directoryNode = _findNodeByPath(fileDir);
        if (directoryNode != null && mounted) {
          setState(() {
            _expandedState[fileDir] = true;
          });
        }
      }
    }
  }

  void _expandToFile(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // Get the relative path from project root
    final relativePath = path.relative(filePath, from: _projectRoot!.path);

    // For organized view, expand the relevant category
    if (_panelMode == PanelMode.organized) {
      String targetCategory = 'Root';

      if (relativePath.startsWith('lib/')) {
        targetCategory = 'Lib';
      } else if (relativePath.startsWith('test/')) {
        targetCategory = 'Tests';
      } else if (relativePath.startsWith('assets/')) {
        targetCategory = 'Assets';
      } else if (relativePath.startsWith('android/') ||
          relativePath.startsWith('ios/') ||
          relativePath.startsWith('web/') ||
          relativePath.startsWith('windows/') ||
          relativePath.startsWith('macos/') ||
          relativePath.startsWith('linux/')) {
        targetCategory = 'Platforms';
      } else if (relativePath.startsWith('build/') ||
          relativePath.startsWith('.dart_tool/') ||
          relativePath.startsWith('benchmark/')) {
        targetCategory = 'Output';
      }

      // Only expand the category if it's not already expanded (respect user choice)
      if (_expandedState['category_$targetCategory'] != false && mounted) {
        setState(() {
          _expandedState['category_$targetCategory'] = true;
        });
      }

      // Ensure the directory containing the file is loaded
      final fileDir = path.dirname(filePath);
      if (fileDir != _projectRoot!.path) {
        final directoryNode = _findNodeByPath(fileDir);
        if (directoryNode != null && directoryNode.children.isEmpty) {
          _ensureDirectoryLoaded(directoryNode);
        }
      }
    } else {
      // For filesystem view, expand directories but respect user choices
      final pathComponents = path.split(relativePath);
      String currentPath = _projectRoot!.path;

      for (final component in pathComponents) {
        if (component == path.basename(filePath)) {
          // This is the file itself, not a directory
          break;
        }

        currentPath = path.join(currentPath, component);

        // Only expand if not explicitly collapsed by user
        if (_expandedState[currentPath] != false && mounted) {
          setState(() {
            _expandedState[currentPath] = true;
          });
        }

        // Find the directory node and ensure it's loaded
        final directoryNode = _findNodeByPath(currentPath);
        if (directoryNode != null && directoryNode.children.isEmpty) {
          _ensureDirectoryLoaded(directoryNode);
        }
      }
    }

    // Ensure the selected file is visible and scroll to it after a short delay to allow the tree to expand
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureSelectedFileVisible(filePath);
        }
      });
    }
  }

  ProjectNode? _findNodeByPath(String targetPath) {
    if (_projectRoot == null) return null;

    // Helper function to search recursively
    ProjectNode? findInNode(ProjectNode node) {
      if (node.path == targetPath) {
        return node;
      }

      for (final child in node.children) {
        final found = findInNode(child);
        if (found != null) {
          return found;
        }
      }

      return null;
    }

    return findInNode(_projectRoot!);
  }

  Widget _getFileIcon(ProjectNode node) {
    final colorScheme = Theme.of(context).colorScheme;

    if (node.isDirectory) {
      return Icon(Icons.folder, color: colorScheme.primary, size: 16);
    }

    final ext = node.fileExtension?.toLowerCase() ?? '';
    switch (ext) {
      case '.dart':
        return Icon(Icons.code, color: colorScheme.primary, size: 16);
      case '.yaml':
      case '.yml':
        return Icon(Icons.settings, color: colorScheme.secondary, size: 16);
      case '.md':
        return Icon(Icons.article, color: colorScheme.secondary, size: 16);
      case '.txt':
        return Icon(
          Icons.article,
          color: colorScheme.onSurfaceVariant,
          size: 16,
        );
      case '.js':
        return Icon(Icons.javascript, color: colorScheme.tertiary, size: 16);
      case '.py':
        return Icon(Icons.code, color: colorScheme.primary, size: 16);
      case '.java':
      case '.kt':
        return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
      case '.gradle':
        return Icon(Icons.build, color: colorScheme.onSurfaceVariant, size: 16);
      case '.xml':
      case '.html':
        return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
      case '.css':
        return Icon(Icons.css, color: colorScheme.primary, size: 16);
      case '.json':
        return Icon(Icons.data_object, color: colorScheme.tertiary, size: 16);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
        return Icon(Icons.image, color: colorScheme.tertiary, size: 16);
      case '.pdf':
        return Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 16);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icon(Icons.archive, color: colorScheme.secondary, size: 16);
      default:
        return Icon(
          Icons.insert_drive_file,
          color: colorScheme.onSurfaceVariant,
          size: 16,
        );
    }
  }

  void _handleContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'open':
        _onNodeTapped(node, _expandedState[node.path] ?? false);
        break;
      case 'new_file':
        _createNewFile(node);
        break;
      case 'new_folder':
        _createNewFolder(node);
        break;
      case 'rename':
        _renameNode(node);
        break;
      case 'delete':
        _deleteNode(node);
        break;
    }
  }

  void _handleFileContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'reveal':
        _revealInFileExplorer(node);
        break;
      case 'rename':
        _renameFile(node);
        break;
      case 'delete':
        _deleteFile(node);
        break;
    }
  }

  void _handleFileTap(ProjectNode node) {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    if (widget.selectedFile?.path == item.path) return;

    // Seed Git status for the selected file if not already loaded
    if (node.gitStatus == GitFileStatus.clean && _projectRoot != null) {
      _seedGitStatusForFile(node);
    }

    // Only trigger file selection if widget is still mounted
    if (widget.onFileSelected != null && mounted) {
      widget.onFileSelected!(item);
    }
  }

  Future<void> _initializeExplorer() async {
    // If an initial project path is provided, load it first
    if (widget.initialProjectPath != null) {
      await _loadProject(widget.initialProjectPath!, forceLoad: true);
    }
  }

  Future<bool> _isFlutterProject(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);

      // Check if pubspec.yaml exists (required for Flutter projects)
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      if (!await pubspecFile.exists()) {
        return false;
      }

      // Check if lib directory exists (typical Flutter project structure)
      final libDir = Directory('${dir.path}/lib');
      if (!await libDir.exists()) {
        return false;
      }

      // Additional check: verify pubspec.yaml contains flutter dependency
      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        return false;
      }

      return true;
    } catch (e) {
      // If we can't read the directory, it's not accessible anyway
      return false;
    }
  }

  Future<void> _loadGitStatus() async {
    if (_projectRoot == null) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(_projectRoot!.path);
      if (!isGitRepo) {
        print('Not a Git repository: ${_projectRoot!.path}');
        return;
      }

      // Get Git status
      final gitStatus = await _gitService.getStatus(_projectRoot!.path);
      print(
        'Git status loaded: ${gitStatus.staged.length} staged, ${gitStatus.unstaged.length} unstaged, ${gitStatus.untracked.length} untracked',
      );

      // Update all nodes with Git status recursively
      _updateNodeGitStatus(_projectRoot!, gitStatus);
    } catch (e) {
      // Silently handle Git status errors
      print('Error loading Git status: $e');
    }
  }

  Future<bool> _loadProject(
    String directoryPath, {
    bool forceLoad = false,
  }) async {
    if (_isLoading && !forceLoad) return false;

    // Validate that this is a Flutter project
    if (!await _isFlutterProject(directoryPath)) {
      _showError(
        'This folder is not a valid Flutter project. FIDE is designed specifically for Flutter development. Please select a folder containing a Flutter project with a pubspec.yaml file.',
      );
      return false;
    }

    // Close current project first
    setState(() {
      _isLoading = true;
      _projectRoot = null;
      _expandedState.clear();
      _loadingDirectories.clear();
    });

    try {
      final root = await ProjectNode.fromFileSystemEntity(
        Directory(directoryPath),
      );
      final result = await root.loadChildren();

      setState(() {
        _projectRoot = root;
      });

      // Notify parent that project is loaded
      if (widget.onProjectLoaded != null) {
        widget.onProjectLoaded!(true);
      }

      // Notify parent of the new project path for MRU update
      if (widget.onProjectPathChanged != null) {
        widget.onProjectPathChanged!(directoryPath);
      }

      // Show user-friendly error messages based on the result
      switch (result) {
        case LoadChildrenResult.accessDenied:
          _showError(
            'Access denied: Cannot read contents of "${root.name}". You may not have permission to view this project folder.',
          );
          return false;
        case LoadChildrenResult.fileSystemError:
          _showError(
            'File system error: Unable to read contents of "${root.name}". The project folder may be corrupted or inaccessible.',
          );
          return false;
        case LoadChildrenResult.unknownError:
          _showError(
            'Unable to load project "${root.name}". Please try again or check if the folder exists.',
          );
          return false;
        case LoadChildrenResult.success:
          // Project loaded successfully

          // Load Git status for the project
          await _loadGitStatus();

          // Check if there's a last opened file to restore
          if (widget.selectedFile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _expandToFile(widget.selectedFile!.path);
            });
          }

          return true;
      }
    } catch (e) {
      _showError('Failed to load project: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onNodeTapped(ProjectNode node, bool isExpanded) async {
    if (node.isDirectory) {
      if (mounted) {
        setState(() {
          _expandedState[node.path] = !isExpanded;
        });
      }

      if (!isExpanded && node.children.isEmpty) {
        try {
          await node.loadChildren();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          if (e.toString().contains('Operation not permitted') ||
              e.toString().contains('Permission denied')) {
            _showError('Access denied: ${node.name}');
          } else {
            _showError('Failed to load directory: $e');
          }
        }
      }
    } else {
      _handleFileTap(node);
    }
  }

  Future<void> _pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        await _loadProject(selectedDirectory);
      }
    } catch (e) {
      _showError('Error loading project: $e');
    }
  }

  Future<void> _refreshProjectTree() async {
    if (_projectRoot == null) return;

    try {
      // Reload the project tree
      final result = await _projectRoot!.loadChildren();

      if (result == LoadChildrenResult.success && mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to refresh project tree: $e');
    }
  }

  Future<void> _renameFile(ProjectNode node) async {
    final TextEditingController controller = TextEditingController(
      text: node.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new file name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == node.name) return;

    try {
      final newPath = path.join(path.dirname(node.path), result);

      // Check if target file already exists
      if (File(newPath).existsSync() || Directory(newPath).existsSync()) {
        _showError('A file or folder with this name already exists');
        return;
      }

      // Perform the rename operation
      if (node.isDirectory) {
        await Directory(node.path).rename(newPath);
      } else {
        await File(node.path).rename(newPath);
      }

      // Update the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      }
    } catch (e) {
      _showError('Failed to rename file: $e');
    }
  }

  void _renameNode(ProjectNode node) {}

  Future<void> _revealInFileExplorer(ProjectNode node) async {
    try {
      final directoryPath = node.isDirectory
          ? node.path
          : path.dirname(node.path);

      if (Platform.isMacOS) {
        // Use 'open' command on macOS
        await Process.run('open', [directoryPath]);
      } else if (Platform.isWindows) {
        // Use 'explorer' command on Windows
        await Process.run('explorer', [directoryPath]);
      } else if (Platform.isLinux) {
        // Use 'xdg-open' command on Linux
        await Process.run('xdg-open', [directoryPath]);
      } else {
        _showError('Reveal in file explorer is not supported on this platform');
      }
    } catch (e) {
      _showError('Failed to open file explorer: $e');
    }
  }

  Future<void> _seedGitStatusForFile(ProjectNode node) async {
    if (_projectRoot == null || !mounted) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(_projectRoot!.path);
      if (!isGitRepo) return;

      // Get Git status for this specific file
      final gitStatus = await _gitService.getStatus(_projectRoot!.path);
      final relativePath = path.relative(node.path, from: _projectRoot!.path);

      if (gitStatus.staged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.added;
      } else if (gitStatus.unstaged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.modified;
      } else if (gitStatus.untracked.contains(relativePath)) {
        node.gitStatus = GitFileStatus.untracked;
      } else {
        node.gitStatus = GitFileStatus.clean;
      }

      // Trigger UI update only if still mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Silently handle errors
      print('Error seeding Git status for file: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      MessageHelper.showError(context, message, showCopyButton: true);
    }
  }

  void _showFileContextMenu(ProjectNode node, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'reveal',
          child: Row(
            children: [
              Icon(
                Platform.isMacOS ? Icons.folder_open : Icons.folder,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(Platform.isMacOS ? 'Reveal in Finder' : 'Show in Explorer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      _handleFileContextMenuAction(value, node);
    });
  }

  void _showNodeContextMenu(ProjectNode node) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        if (node.isDirectory) ...[
          const PopupMenuItem(value: 'new_file', child: Text('New File')),
          const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
        ],
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      _handleContextMenuAction(value, node);
    });
  }

  void _updateNodeGitStatus(ProjectNode node, GitStatus gitStatus) {
    if (node.isFile) {
      final relativePath = path.relative(node.path, from: _projectRoot!.path);

      if (gitStatus.staged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.added;
        print('File ${node.name} marked as ADDED');
      } else if (gitStatus.unstaged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.modified;
        print('File ${node.name} marked as MODIFIED');
      } else if (gitStatus.untracked.contains(relativePath)) {
        node.gitStatus = GitFileStatus.untracked;
        print('File ${node.name} marked as UNTRACKED');
      } else {
        node.gitStatus = GitFileStatus.clean;
      }
    }

    // Recursively update children
    for (final child in node.children) {
      _updateNodeGitStatus(child, gitStatus);
    }
  }
}
