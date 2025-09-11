import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';

class ExplorerScreen extends StatefulWidget {
  final Function(FileSystemItem)? onFileSelected;

  const ExplorerScreen({super.key, this.onFileSelected});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  static const String _lastOpenedFolderKey = 'last_opened_folder';

  ProjectNode? _projectRoot;
  bool _isLoading = false;
  final Map<String, bool> _expandedState = {};
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadLastOpenedFolder();
  }

  Future<void> _loadLastOpenedFolder() async {
    _prefs = await SharedPreferences.getInstance();
    final lastFolder = _prefs.getString(_lastOpenedFolderKey);
    if (lastFolder != null && await Directory(lastFolder).exists()) {
      await _loadProject(lastFolder);
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

  Future<void> _loadProject(String directoryPath) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final root = await ProjectNode.fromFileSystemEntity(
        Directory(directoryPath),
      );
      await root.loadChildren();

      // Save the opened folder path
      await _prefs.setString(_lastOpenedFolderKey, directoryPath);

      setState(() {
        _projectRoot = root;
      });
    } catch (e) {
      _showError('Failed to load project: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickDirectory,
            tooltip: 'Open Project',
          ),
          if (_projectRoot != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadProject(_projectRoot!.path),
              tooltip: 'Refresh',
            ),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.folder, color: Colors.blue),
          title: Text(node.name),
          trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => _onNodeTapped(node, isExpanded),
          onLongPress: () => _showNodeContextMenu(node),
        ),
        if (node.isDirectory && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: _buildNodeChildren(node),
          ),
      ],
    );
  }

  Widget _buildFileNode(ProjectNode node) {
    return ListTile(
      leading: _getFileIcon(node),
      title: Text(node.name),
      onTap: () => _handleFileTap(node),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
    );
  }

  Widget _buildNodeChildren(ProjectNode node) {
    if (node.children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text('Empty directory', style: TextStyle(color: Colors.grey)),
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

      // Load children if not already loaded
      if (!isExpanded && node.children.isEmpty) {
        try {
          await node.loadChildren();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          _showError('Failed to load directory: $e');
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
  void _createNewFile(ProjectNode parent) {
    // Implementation needed
  }

  void _createNewFolder(ProjectNode parent) {
    // Implementation needed
  }

  void _renameNode(ProjectNode node) {
    // Implementation needed
  }

  void _deleteNode(ProjectNode node) {
    // Implementation needed
  }

  Widget _getFileIcon(ProjectNode node) {
    if (node.isDirectory) {
      return const Icon(Icons.folder, color: Colors.blue);
    }

    final ext = node.fileExtension?.toLowerCase() ?? '';
    switch (ext) {
      case '.dart':
        return const Icon(Icons.code, color: Colors.blue);
      case '.yaml':
      case '.yml':
        return const Icon(Icons.settings, color: Colors.blueGrey);
      case '.md':
        return const Icon(Icons.article, color: Colors.blueGrey);
      case '.txt':
        return const Icon(Icons.article, color: Colors.grey);
      case '.js':
        return const Icon(Icons.javascript, color: Colors.amber);
      case '.py':
        return const Icon(Icons.code, color: Colors.blue);
      case '.java':
      case '.kt':
        return const Icon(Icons.code, color: Colors.orange);
      case '.gradle':
        return const Icon(Icons.build, color: Colors.grey);
      case '.xml':
      case '.html':
        return const Icon(Icons.code, color: Colors.green);
      case '.css':
        return const Icon(Icons.css, color: Colors.blue);
      case '.json':
        return const Icon(Icons.data_object, color: Colors.amber);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
        return const Icon(Icons.image, color: Colors.purple);
      case '.pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return const Icon(Icons.archive, color: Colors.blueGrey);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }
}
