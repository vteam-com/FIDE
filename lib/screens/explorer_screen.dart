// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/message_helper.dart';
import 'package:fide/screens/welcome_screen.dart';
import 'package:fide/screens/git_panel.dart';
import 'package:fide/theme/app_theme.dart';

enum PanelMode { filesystem, organized, git }

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.initialProjectPath,
    this.showGitPanel = false,
    this.onToggleGitPanel,
  });

  final String? initialProjectPath;

  final Function(FileSystemItem)? onFileSelected;

  final Function(bool)? onProjectLoaded;

  final Function(String)? onProjectPathChanged;

  final Function(ThemeMode)? onThemeChanged;

  final VoidCallback? onToggleGitPanel;

  final FileSystemItem? selectedFile;

  final bool showGitPanel;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final Map<String, bool> _expandedState = {};

  bool _isLoading = false;

  final Set<String> _loadingDirectories = {};

  PanelMode _panelMode = PanelMode.filesystem;

  static const String _panelModeKey = 'explorer_panel_mode';

  SharedPreferences? _prefs;

  ProjectNode? _projectRoot;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeExplorer();
  }

  @override
  void didUpdateWidget(ExplorerScreen oldWidget) {
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
  }

  @override
  Widget build(BuildContext context) {
    // Ensure selected file is expanded and visible when building
    if (widget.selectedFile != null && _projectRoot != null && !_isLoading) {
      // Use a microtask to ensure this happens after the current build cycle
      Future.microtask(() {
        if (mounted) {
          _expandToFile(widget.selectedFile!.path);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle(), actions: []),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: AppTheme.sidePanelBackground(context),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _projectRoot == null
                  ? WelcomeScreen(
                      onOpenFolder: _pickDirectory,
                      onCreateProject: _createNewProject,
                      mruFolders: _prefs?.getStringList('mru_folders') ?? [],
                      onOpenMruProject: _loadProject,
                      onRemoveMruEntry: _removeMruEntry,
                    )
                  : widget.showGitPanel
                  ? _buildGitPanel()
                  : _buildFileExplorer(),
            ),
          ),
          if (_projectRoot != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: AppTheme.sidePanelSurface(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Normal File View Button
                  _buildToggleButton(
                    icon: Icons.folder,
                    tooltip: 'Normal File View',
                    isSelected:
                        !widget.showGitPanel &&
                        _panelMode == PanelMode.filesystem,
                    onPressed: () {
                      if (widget.showGitPanel) {
                        widget.onToggleGitPanel?.call();
                      }
                      if (_panelMode != PanelMode.filesystem) {
                        _togglePanelMode();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Organized File View Button
                  _buildToggleButton(
                    icon: Icons.folder_special,
                    tooltip: 'Organized File View',
                    isSelected:
                        !widget.showGitPanel &&
                        _panelMode == PanelMode.organized,
                    onPressed: () {
                      if (widget.showGitPanel) {
                        widget.onToggleGitPanel?.call();
                      }
                      if (_panelMode != PanelMode.organized) {
                        _togglePanelMode();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Git Panel Button
                  _buildToggleButton(
                    icon: Icons.account_tree,
                    tooltip: 'Git Panel',
                    isSelected: widget.showGitPanel,
                    onPressed: widget.onToggleGitPanel ?? () {},
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

  Widget _buildAppBarTitle() {
    // Load MRU folders for display purposes
    final mruList = _prefs?.getStringList('mru_folders') ?? [];
    final mruFolders = mruList
        .where((path) => Directory(path).existsSync())
        .toList();

    if (_projectRoot == null) {
      return Text(
        'Explorer',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      );
    }

    return PopupMenuButton<String>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _projectRoot?.name ?? 'Folder...',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onSelected: (value) {
        if (value == 'add_folder') {
          _pickDirectory();
        } else if (value == 'create_project') {
          _createNewProject();
        } else if (value == 'close_project') {
          _closeProject();
        } else if (value.startsWith('remove_')) {
          // Handle MRU entry removal
          final pathToRemove = value.substring(7); // Remove 'remove_' prefix
          _removeMruEntry(pathToRemove);
        } else {
          _loadProject(value, forceLoad: true);
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        for (final path in mruFolders) {
          final dirName = path.split('/').last;
          final hasAccess = Directory(path).existsSync();
          items.add(
            PopupMenuItem<String>(
              value: path,
              child: Row(
                children: [
                  Icon(
                    hasAccess ? Icons.folder : Icons.folder_off,
                    color: hasAccess
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dirName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasAccess
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (!hasAccess) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.error,
                      size: 14,
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      _removeMruEntry(path);
                      Navigator.of(context).pop();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          );
        }

        if (mruFolders.isNotEmpty) {
          items.add(const PopupMenuDivider());
        }

        items.add(
          PopupMenuItem<String>(
            value: 'add_folder',
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Open a folder ...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );

        items.add(
          PopupMenuItem<String>(
            value: 'create_project',
            child: Row(
              children: [
                Icon(
                  Icons.create_new_folder,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create new Project...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );

        items.add(
          PopupMenuItem<String>(
            value: 'close_project',
            child: Row(
              children: [
                Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Close Project',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );

        return items;
      },
    );
  }

  Widget _buildCategorySection(String category, List<ProjectNode> nodes) {
    final isExpanded = _expandedState['category_$category'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        InkWell(
          onTap: () {
            setState(() {
              _expandedState['category_$category'] = !isExpanded;
            });
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
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildNodeChildren(node),
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: _projectRoot!.children.length,
      itemBuilder: (context, index) {
        final node = _projectRoot!.children[index];
        return _buildNode(node);
      },
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

    // Determine text color based on selection and hidden status
    Color textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
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
              // Add selection indicator
              if (isSelected) ...[
                Container(
                  width: 3,
                  height: 16,
                  color: Theme.of(context).colorScheme.primary,
                  margin: const EdgeInsets.only(right: 5),
                ),
              ],
              _getFileIcon(node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add selection checkmark
              if (isSelected) ...[
                Icon(
                  Icons.check,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
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
      return Container(
        color: AppTheme.sidePanelBackground(context),
        child: const Center(child: Text('No project loaded')),
      );
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

    return ListView(controller: _scrollController, children: sections);
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
              : Colors.transparent,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  void _calculateNodePosition(
    ProjectNode node,
    String targetPath,
    int position,
  ) {
    if (node.path == targetPath) {
      return;
    }

    for (final child in node.children) {
      position++;
      if (child.path == targetPath) {
        return;
      }

      if (child.isDirectory && (_expandedState[child.path] ?? false)) {
        _calculateNodePosition(child, targetPath, position);
      }
    }
  }

  void _closeProject() {
    if (_projectRoot == null) return;

    setState(() {
      _projectRoot = null;
      _expandedState.clear();
      _loadingDirectories.clear();
    });

    // Notify parent that project is closed
    if (widget.onProjectLoaded != null) {
      widget.onProjectLoaded!(false);
    }

    // Notify parent that project path is cleared
    if (widget.onProjectPathChanged != null) {
      widget.onProjectPathChanged!('');
    }
  }

  void _createNewFile(ProjectNode parent) {}

  void _createNewFolder(ProjectNode parent) {}

  Future<void> _createNewProject() async {
    if (_projectRoot == null) {
      _showError('No current project loaded. Please open a project first.');
      return;
    }

    final parentDir = path.dirname(_projectRoot!.path);

    final TextEditingController controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Flutter Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name (will be converted to snake_case)',
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final snakeName = _toSnakeCase(result);

    if (snakeName.isEmpty) {
      _showError('Invalid project name.');
      return;
    }

    // Check if directory already exists
    final projectPath = path.join(parentDir, snakeName);
    if (Directory(projectPath).existsSync()) {
      _showError(
        'A project with this name already exists in the parent directory.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Run flutter create command
      final result = await Process.run('flutter', [
        'create',
        snakeName,
      ], workingDirectory: parentDir);

      if (result.exitCode == 0) {
        // Wait a bit for the file system to update
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the project was created
        if (Directory(projectPath).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Project "$snakeName" created successfully!'),
              ),
            );
            // Load the new project
            await _loadProject(projectPath);
          }
        } else {
          _showError(
            'Project directory was not created. Please check if Flutter is installed and try again.',
          );
        }
      } else {
        _showError('Failed to create project: ${result.stderr}');
      }
    } catch (e) {
      _showError('Failed to create project: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (_projectRoot == null) return;

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

      setState(() {
        _expandedState['category_$targetCategory'] = true;
      });
    } else {
      // For filesystem view, expand the directory containing the file
      final fileDir = path.dirname(filePath);
      if (fileDir != _projectRoot!.path) {
        final directoryNode = _findNodeByPath(fileDir);
        if (directoryNode != null) {
          setState(() {
            _expandedState[fileDir] = true;
          });
        }
      }
    }

    // Simple scroll to make sure the file is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _simpleScrollToFile(filePath);
    });
  }

  void _expandToFile(String filePath) {
    if (_projectRoot == null) return;

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
      if (_expandedState['category_$targetCategory'] != false) {
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
        if (_expandedState[currentPath] != false) {
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

    // Scroll to the selected file after a short delay to allow the tree to expand
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedFile(filePath);
    });
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

  void _handleFileTap(ProjectNode node) {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    if (widget.selectedFile?.path == item.path) return;
    if (widget.onFileSelected != null) {
      widget.onFileSelected!(item);
    }
  }

  Future<void> _initializeExplorer() async {
    // Always initialize SharedPreferences first
    _prefs = await SharedPreferences.getInstance();

    // Load saved panel mode
    final savedPanelMode = _prefs!.getString(_panelModeKey);
    if (savedPanelMode != null) {
      setState(() {
        _panelMode = savedPanelMode == 'organized'
            ? PanelMode.organized
            : PanelMode.filesystem;
      });
    }

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
      setState(() {
        _expandedState[node.path] = !isExpanded;
      });

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

  Future<void> _removeMruEntry(String directoryPath) async {
    if (_prefs == null) return;

    final mruList = _prefs!.getStringList('mru_folders') ?? [];
    mruList.remove(directoryPath);

    await _prefs!.setStringList('mru_folders', mruList);

    // Force a rebuild to update the UI
    if (mounted) {
      setState(() {});
    }
  }

  void _renameNode(ProjectNode node) {}

  void _scrollToSelectedFile(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // Check if ScrollController is properly attached
    if (!_scrollController.hasClients) return;

    // Calculate the approximate position of the file in the tree
    double scrollOffset = 0.0;
    const double itemHeight = 24.0; // Approximate height of each tree item
    const double categoryHeaderHeight = 32.0; // Height of category headers

    if (_panelMode == PanelMode.organized) {
      // Handle organized view scrolling
      final relativePath = path.relative(filePath, from: _projectRoot!.path);

      // Find which category the file belongs to
      String targetCategory = 'Root';
      ProjectNode? parentDir;

      // Check if file is in lib directory
      final libDir = _projectRoot!.children.firstWhere(
        (node) => node.name == 'lib' && node.isDirectory,
        orElse: () =>
            ProjectNode(name: '', path: '', type: ProjectNodeType.file),
      );
      if (libDir.path.isNotEmpty && relativePath.startsWith('lib/')) {
        targetCategory = 'Lib';
        parentDir = libDir;
      }

      // Check if file is in test directory
      final testDir = _projectRoot!.children.firstWhere(
        (node) => node.name == 'test' && node.isDirectory,
        orElse: () =>
            ProjectNode(name: '', path: '', type: ProjectNodeType.file),
      );
      if (testDir.path.isNotEmpty && relativePath.startsWith('test/')) {
        targetCategory = 'Tests';
        parentDir = testDir;
      }

      // Check if file is in assets directory
      final assetsDir = _projectRoot!.children.firstWhere(
        (node) => node.name == 'assets' && node.isDirectory,
        orElse: () =>
            ProjectNode(name: '', path: '', type: ProjectNodeType.file),
      );
      if (assetsDir.path.isNotEmpty && relativePath.startsWith('assets/')) {
        targetCategory = 'Assets';
        parentDir = assetsDir;
      }

      // Calculate scroll position for organized view
      final categories = [
        'Root',
        'Lib',
        'Tests',
        'Assets',
        'Platforms',
        'Output',
      ];
      final categoryIndex = categories.indexOf(targetCategory);

      // Add height for previous categories
      for (int i = 0; i < categoryIndex; i++) {
        scrollOffset += categoryHeaderHeight;
        // Add some space for items in previous categories (approximate)
        scrollOffset += 50.0;
      }

      // Add category header height
      scrollOffset += categoryHeaderHeight;

      // Find the position of the file within its category
      if (parentDir != null && parentDir.children.isNotEmpty) {
        final fileIndex = parentDir.children.indexWhere(
          (node) => node.path == filePath,
        );
        if (fileIndex >= 0) {
          scrollOffset += fileIndex * itemHeight;
        }
      }
    } else {
      // Handle filesystem view scrolling
      final fileNode = _findNodeByPath(filePath);
      if (fileNode != null) {
        // Calculate position based on tree structure
        int position = 0;
        _calculateNodePosition(_projectRoot!, filePath, position);
        scrollOffset = position * itemHeight;
      }
    }

    // Scroll to the calculated position with animation
    try {
      _scrollController.animateTo(
        scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      // Silently handle scroll errors
      debugPrint('Scroll error in _scrollToSelectedFile: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      MessageHelper.showError(context, message, showCopyButton: true);
    }
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

  void _simpleScrollToFile(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // Check if ScrollController is properly attached
    if (!_scrollController.hasClients) return;

    // Find the file node
    final fileNode = _findNodeByPath(filePath);
    if (fileNode == null) return;

    // Calculate a simple scroll position
    double scrollOffset = 0.0;

    if (_panelMode == PanelMode.organized) {
      // For organized view, scroll to the category
      final relativePath = path.relative(filePath, from: _projectRoot!.path);
      if (relativePath.startsWith('lib/')) {
        scrollOffset = 100.0; // Approximate position of Lib category
      } else if (relativePath.startsWith('test/')) {
        scrollOffset = 200.0; // Approximate position of Tests category
      } else if (relativePath.startsWith('assets/')) {
        scrollOffset = 300.0; // Approximate position of Assets category
      }
      // For other categories, keep at top
    } else {
      // For filesystem view, scroll to middle of visible area
      try {
        scrollOffset = _scrollController.position.maxScrollExtent * 0.3;
      } catch (e) {
        // Handle case where position is not available
        scrollOffset = 0.0;
      }
    }

    try {
      _scrollController.animateTo(
        scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      // Silently handle scroll errors
      debugPrint('Scroll error in _simpleScrollToFile: $e');
    }
  }

  String _toSnakeCase(String input) {
    return input.replaceAll(' ', '_').toLowerCase();
  }

  void _togglePanelMode() {
    final newPanelMode = _panelMode == PanelMode.filesystem
        ? PanelMode.organized
        : PanelMode.filesystem;

    setState(() {
      _panelMode = newPanelMode;
    });

    // Save the new panel mode to SharedPreferences
    _prefs?.setString(
      _panelModeKey,
      newPanelMode == PanelMode.organized ? 'organized' : 'filesystem',
    );

    // After switching panel mode, ensure the selected file is still visible
    if (widget.selectedFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedFileVisible(widget.selectedFile!.path);
      });
    }
  }
}
