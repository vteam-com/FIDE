// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/widgets/message_widget.dart';

enum ViewMode { filesystem, organized }

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.initialProjectPath,
  });

  final String? initialProjectPath;

  final Function(FileSystemItem)? onFileSelected;

  final Function(bool)? onProjectLoaded;

  final Function(ThemeMode)? onThemeChanged;

  final FileSystemItem? selectedFile;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final Map<String, bool> _expandedState = {};

  bool _isLoading = false;

  static const int _maxMruItems = 5;

  final Map<String, bool> _mruAccessStatus = {};

  List<String> _mruFolders = [];

  static const String _mruFoldersKey = 'mru_folders';

  late SharedPreferences _prefs;

  ProjectNode? _projectRoot;

  ViewMode _viewMode = ViewMode.filesystem;

  @override
  void initState() {
    super.initState();
    _initializeExplorer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _mruFolders.isNotEmpty
            ? PopupMenuButton<String>(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _projectRoot?.name ?? 'Folder...',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
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
                  } else {
                    _loadProject(value, forceLoad: true);
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];

                  for (final path in _mruFolders) {
                    final dirName = path.split('/').last;
                    final hasAccess =
                        _mruAccessStatus[path] ??
                        true; // Default to true if not checked yet
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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

                  if (_mruFolders.isNotEmpty) {
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

                  return items;
                },
              )
            : ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Folder'),
                onPressed: _pickDirectory,
              ),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == ViewMode.filesystem
                  ? Icons.view_list
                  : Icons.folder_special,
            ),
            onPressed: _toggleViewMode,
            tooltip: _viewMode == ViewMode.filesystem
                ? 'Switch to Organized View'
                : 'Switch to Filesystem View',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projectRoot == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No project opened',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open Flutter Project'),
                  ),
                ],
              ),
            )
          : _buildFileExplorer(),
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
      return Center(
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
      );
    }

    if (_viewMode == ViewMode.organized) {
      return _buildOrganizedView();
    }

    return ListView.builder(
      itemCount: _projectRoot!.children.length,
      itemBuilder: (context, index) {
        final node = _projectRoot!.children[index];
        return _buildNode(node);
      },
    );
  }

  Widget _buildFileNode(ProjectNode node) {
    final isSelected =
        widget.selectedFile != null && widget.selectedFile!.path == node.path;

    // Determine text color based on selection and hidden status
    Color textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    return InkWell(
      onTap: () => _handleFileTap(node),
      onLongPress: () => _showNodeContextMenu(node),
      hoverColor: Colors.blue.withOpacity(0.1),
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            children: [
              _getFileIcon(node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return _buildDirectoryNode(node);
    } else {
      return _buildFileNode(node);
    }
  }

  Widget _buildNodeChildren(ProjectNode node) {
    if (node.children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
        child: Text(
          'Empty folder',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: node.children.map((child) => _buildNode(child)).toList(),
    );
  }

  void _createNewFile(ProjectNode parent) {}

  void _createNewFolder(ProjectNode parent) {}

  void _deleteNode(ProjectNode node) {}

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
    if (widget.onFileSelected != null) {
      widget.onFileSelected!(
        FileSystemItem.fromFileSystemEntity(File(node.path)),
      );
    }
  }

  Future<void> _initializeExplorer() async {
    // Always initialize SharedPreferences first
    _prefs = await SharedPreferences.getInstance();

    // If an initial project path is provided, load it first
    if (widget.initialProjectPath != null) {
      await _loadProject(widget.initialProjectPath!, forceLoad: true);
    } else {
      // Otherwise, load MRU folders as usual
      await _loadMruFolders();
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

  Future<void> _loadMruFolders() async {
    final mruList = _prefs.getStringList(_mruFoldersKey) ?? [];

    // Keep all folders in MRU but check their access status
    setState(() {
      _mruFolders = mruList
          .where((path) => Directory(path).existsSync())
          .toList();
    });

    // Load the most recent folder if available
    if (_mruFolders.isNotEmpty) {
      await _loadProject(_mruFolders.first);
    } else {
      // No MRU folders available, notify parent that no project is loaded
      if (widget.onProjectLoaded != null) {
        widget.onProjectLoaded!(false);
      }
    }
  }

  Future<void> _loadProject(
    String directoryPath, {
    bool forceLoad = false,
  }) async {
    if (_isLoading && !forceLoad) return;

    // Validate that this is a Flutter project
    if (!await _isFlutterProject(directoryPath)) {
      _showError(
        'This folder is not a valid Flutter project. FIDE is designed specifically for Flutter development. Please select a folder containing a Flutter project with a pubspec.yaml file.',
      );
      return;
    }

    // Close current project first
    setState(() {
      _isLoading = true;
      _projectRoot = null;
      _expandedState.clear();
    });

    try {
      final root = await ProjectNode.fromFileSystemEntity(
        Directory(directoryPath),
      );
      final result = await root.loadChildren();

      // Update MRU list
      await _updateMruList(directoryPath);

      setState(() {
        _projectRoot = root;
      });

      // Notify parent that project is loaded
      if (widget.onProjectLoaded != null) {
        widget.onProjectLoaded!(true);
      }

      // Show user-friendly error messages based on the result
      switch (result) {
        case LoadChildrenResult.accessDenied:
          _showError(
            'Access denied: Cannot read contents of "${root.name}". You may not have permission to view this project folder.',
          );
          break;
        case LoadChildrenResult.fileSystemError:
          _showError(
            'File system error: Unable to read contents of "${root.name}". The project folder may be corrupted or inaccessible.',
          );
          break;
        case LoadChildrenResult.unknownError:
          _showError(
            'Unable to load project "${root.name}". Please try again or check if the folder exists.',
          );
          break;
        case LoadChildrenResult.success:
          // No error to show
          break;
      }
    } catch (e) {
      _showError('Failed to load project: $e');
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
    setState(() {
      _mruFolders.remove(directoryPath);
    });

    await _prefs.setStringList(_mruFoldersKey, _mruFolders);
  }

  void _renameNode(ProjectNode node) {}

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

  Future<void> _updateMruList(String directoryPath) async {
    _mruFolders.remove(directoryPath); // Move to front if exists
    _mruFolders.insert(0, directoryPath);

    if (_mruFolders.length > _maxMruItems) {
      _mruFolders = _mruFolders.sublist(0, _maxMruItems);
    }

    await _prefs.setStringList(_mruFoldersKey, _mruFolders);
    setState(() {});
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ViewMode.filesystem
          ? ViewMode.organized
          : ViewMode.filesystem;
    });
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

    // Add lib contents if available
    if (libDir != null && libDir.children.isNotEmpty) {
      categories['Lib']!.addAll(libDir.children);
    }

    // Add test contents if available
    if (testDir != null && testDir.children.isNotEmpty) {
      categories['Tests']!.addAll(testDir.children);
    }

    // Add assets contents if available
    if (assetsDir != null && assetsDir.children.isNotEmpty) {
      categories['Assets']!.addAll(assetsDir.children);
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

    return ListView(children: sections);
  }

  Widget _buildCategorySection(String category, List<ProjectNode> nodes) {
    final isExpanded = _expandedState['category_$category'] ?? true;

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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
}
