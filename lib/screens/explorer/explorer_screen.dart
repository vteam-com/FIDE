// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/widgets/message_widget.dart';

class ExplorerScreen extends StatefulWidget {
  final Function(FileSystemItem)? onFileSelected;
  final FileSystemItem? selectedFile;

  const ExplorerScreen({super.key, this.onFileSelected, this.selectedFile});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  static const String _mruFoldersKey = 'mru_folders';
  static const int _maxMruItems = 5;

  ProjectNode? _projectRoot;
  bool _isLoading = false;
  final Map<String, bool> _expandedState = {};
  late SharedPreferences _prefs;
  List<String> _mruFolders = [];
  final Map<String, bool> _mruAccessStatus = {};

  @override
  void initState() {
    super.initState();
    _loadMruFolders();
  }

  Future<void> _loadMruFolders() async {
    _prefs = await SharedPreferences.getInstance();
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

  Future<void> _updateMruList(String directoryPath) async {
    _mruFolders.remove(directoryPath); // Move to front if exists
    _mruFolders.insert(0, directoryPath);

    if (_mruFolders.length > _maxMruItems) {
      _mruFolders = _mruFolders.sublist(0, _maxMruItems);
    }

    await _prefs.setStringList(_mruFoldersKey, _mruFolders);
    setState(() {});
  }

  Future<void> _removeMruEntry(String directoryPath) async {
    setState(() {
      _mruFolders.remove(directoryPath);
    });

    await _prefs.setStringList(_mruFoldersKey, _mruFolders);
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

  void _showError(String message) {
    if (mounted) {
      MessageHelper.showError(context, message, showCopyButton: true);
    }
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
                    Expanded(
                      child: Text(
                        _projectRoot?.name ?? 'Project Explorer',
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
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
                              color: hasAccess ? Colors.blue : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dirName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasAccess ? null : Colors.red,
                                ),
                              ),
                            ),
                            if (!hasAccess) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.lock,
                                color: Colors.red,
                                size: 14,
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
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
                    const PopupMenuItem<String>(
                      value: 'add_folder',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 8),
                          Text('Open a folder ...'),
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
                ],
              ),
            )
          : _buildFileExplorer(),
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

    return ListView.builder(
      itemCount: _projectRoot!.children.length,
      itemBuilder: (context, index) {
        final node = _projectRoot!.children[index];
        return _buildNode(node);
      },
    );
  }

  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return _buildDirectoryNode(node);
    } else {
      return _buildFileNode(node);
    }
  }

  Widget _buildDirectoryNode(ProjectNode node) {
    final isExpanded = _expandedState[node.path] ?? false;
    final hasError =
        node.loadResult != null &&
        node.loadResult != LoadChildrenResult.success;

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
                  color: hasError ? Colors.red : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasError ? Colors.red : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(width: 4),
                  Icon(
                    node.loadResult == LoadChildrenResult.accessDenied
                        ? Icons.lock
                        : Icons.error,
                    color: Colors.red,
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

  Widget _buildFileNode(ProjectNode node) {
    final isSelected =
        widget.selectedFile != null && widget.selectedFile!.path == node.path;

    return InkWell(
      onTap: () => _handleFileTap(node),
      onLongPress: () => _showNodeContextMenu(node),
      hoverColor: Colors.blue.withOpacity(0.1),
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
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
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
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

  void _handleFileTap(ProjectNode node) {
    if (widget.onFileSelected != null) {
      widget.onFileSelected!(
        FileSystemItem.fromFileSystemEntity(File(node.path)),
      );
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

  // TODO: Implement these methods
  void _createNewFile(ProjectNode parent) {}
  void _createNewFolder(ProjectNode parent) {}
  void _renameNode(ProjectNode node) {}
  void _deleteNode(ProjectNode node) {}

  Widget _getFileIcon(ProjectNode node) {
    if (node.isDirectory) {
      return const Icon(Icons.folder, color: Colors.blue, size: 16);
    }

    final ext = node.fileExtension?.toLowerCase() ?? '';
    switch (ext) {
      case '.dart':
        return const Icon(Icons.code, color: Colors.blue, size: 16);
      case '.yaml':
      case '.yml':
        return const Icon(Icons.settings, color: Colors.blueGrey, size: 16);
      case '.md':
        return const Icon(Icons.article, color: Colors.blueGrey, size: 16);
      case '.txt':
        return const Icon(Icons.article, color: Colors.grey, size: 16);
      case '.js':
        return const Icon(Icons.javascript, color: Colors.amber, size: 16);
      case '.py':
        return const Icon(Icons.code, color: Colors.blue, size: 16);
      case '.java':
      case '.kt':
        return const Icon(Icons.code, color: Colors.orange, size: 16);
      case '.gradle':
        return const Icon(Icons.build, color: Colors.grey, size: 16);
      case '.xml':
      case '.html':
        return const Icon(Icons.code, color: Colors.green, size: 16);
      case '.css':
        return const Icon(Icons.css, color: Colors.blue, size: 16);
      case '.json':
        return const Icon(Icons.data_object, color: Colors.amber, size: 16);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
        return const Icon(Icons.image, color: Colors.purple, size: 16);
      case '.pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return const Icon(Icons.archive, color: Colors.blueGrey, size: 16);
      default:
        return const Icon(
          Icons.insert_drive_file,
          color: Colors.grey,
          size: 16,
        );
    }
  }
}
