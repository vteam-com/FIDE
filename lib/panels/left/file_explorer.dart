// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_print

import 'dart:io';
import 'package:fide/utils/file_type_utils.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:fide/services/file_system_service.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:path/path.dart' as path;
import 'directory_contents.dart';

class FileExplorer extends StatefulWidget {
  const FileExplorer({
    super.key,
    this.initialPath,
    this.onFileSelected,
    this.onDirectoryChanged,
  });

  final String? initialPath;

  final ValueChanged<String>? onDirectoryChanged;

  final ValueChanged<String>? onFileSelected;

  @override
  FileExplorerState createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer> {
  final Logger _logger = Logger('FileExplorerState');

  late String _currentPath;

  final Map<String, List<FileSystemItem>> _expandedItems = {};

  final FileSystemService _fileSystem = FileSystemService();

  final GitService _gitService = GitService();

  bool _isLoading = false;

  List<FileSystemItem> _items = [];

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  String? _searchQuery;

  String? _selectedPath;

  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? path.separator;
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: _currentPath.split(path.separator).length > 1
                    ? () {
                        final parentPath = path.dirname(_currentPath);
                        _navigateTo(parentPath);
                      }
                    : null,
                tooltip: 'Go up',
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadDirectory,
                tooltip: 'Refresh',
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _showSearch
                    ? TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.isNotEmpty ? value : null;
                          });
                        },
                      )
                    : Text(
                        path.basename(_currentPath),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              if (!_showSearch) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _toggleSearch,
                  tooltip: 'Search',
                  iconSize: 20,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
              if (_showSearch)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _toggleSearch,
                  tooltip: 'Close search',
                  iconSize: 20,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),

        // Breadcrumb
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _buildBreadcrumbs()),
          ),
        ),

        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(child: Text('Empty folder'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    if (_searchQuery != null &&
                        !item.name.toLowerCase().contains(
                          _searchQuery!.toLowerCase(),
                        )) {
                      return const SizedBox.shrink();
                    }
                    return _buildItem(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbItem(String name, int index) {
    final parts = _currentPath.split(path.separator);
    String pathToHere = '';

    if (Platform.isWindows && parts[0].endsWith(':')) {
      // Windows path
      pathToHere = parts[0] + path.separator;
      for (int i = 1; i <= index; i++) {
        if (parts[i].isNotEmpty) {
          pathToHere = path.join(pathToHere, parts[i]);
        }
      }
    } else {
      // Unix path
      for (int i = 0; i <= index; i++) {
        if (parts[i].isNotEmpty) {
          pathToHere = path.join(pathToHere, parts[i]);
        }
      }
      if (_currentPath.startsWith('/')) {
        pathToHere = '/$pathToHere';
      }
    }

    return GestureDetector(
      onTap: () => _navigateTo(pathToHere),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
          child: Text(
            name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    final parts = _currentPath.split(path.separator);
    final breadcrumbs = <Widget>[];

    // Handle Windows drive letters
    if (Platform.isWindows && parts.isNotEmpty && parts[0].endsWith(':')) {
      breadcrumbs.add(_buildBreadcrumbItem(parts[0] + path.separator, 0));
      breadcrumbs.add(const Text(' > '));

      for (int i = 1; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        breadcrumbs.add(_buildBreadcrumbItem(parts[i], i));
        if (i < parts.length - 1) {
          breadcrumbs.add(const Text(' > '));
        }
      }
    } else {
      // Handle Unix-style paths
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        breadcrumbs.add(_buildBreadcrumbItem(parts[i], i));
        if (i < parts.length - 1) {
          breadcrumbs.add(const Text(' > '));
        }
      }
    }

    return breadcrumbs;
  }

  Widget _buildItem(FileSystemItem item) {
    final isSelected = _selectedPath == item.path;
    final isDirectory = item.type == FileSystemItemType.directory;
    final isParent = item.type == FileSystemItemType.parent;

    // Get Git status styling
    final gitTextStyle = item.getGitStatusTextStyle(context);
    final badgeText = item.getGitStatusBadge();

    // Debug output
    if (item.type == FileSystemItemType.file &&
        item.gitStatus != GitFileStatus.clean) {
      _logger.info(
        'Building item ${item.name} with Git status: ${item.gitStatus}, badge: $badgeText',
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isParent
                  ? const Icon(Icons.folder_special)
                  : isDirectory
                  ? const Icon(Icons.folder)
                  : FileIconUtils.getFileIcon(item),
              if (badgeText.isNotEmpty && !isDirectory && !isParent)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: item.getGitStatusColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.getGitStatusColor(context),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            item.name,
            style: gitTextStyle.copyWith(
              fontWeight: isSelected
                  ? FontWeight.bold
                  : gitTextStyle.fontWeight,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : gitTextStyle.color ??
                        Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          trailing: isDirectory
              ? Icon(
                  item.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                )
              : null,
          onTap: () => _toggleExpand(item),
          onLongPress: () => _showContextMenu(item),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          selected: isSelected,
        ),
        if (isDirectory && item.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: DirectoryContents(
              path: item.path,
              onFileSelected: widget.onFileSelected,
              selectedPath: _selectedPath,
              onItemSelected: (path) {
                setState(() => _selectedPath = path);
              },
            ),
          ),
      ],
    );
  }

  void _createNewFile(String parentPath) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File name',
            hintText: 'example.dart',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final fileName = controller.text.trim();
              if (fileName.isNotEmpty) {
                final filePath = path.join(parentPath, fileName);
                try {
                  await _fileSystem.createFile(filePath);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadDirectory();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating file: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createNewFolder(String parentPath) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'New Folder',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final folderName = controller.text.trim();
              if (folderName.isNotEmpty) {
                final folderPath = path.join(parentPath, folderName);
                try {
                  await _fileSystem.createDirectory(folderPath);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadDirectory();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating folder: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(FileSystemItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _fileSystem.delete(item.path);
                if (mounted) {
                  Navigator.pop(context);
                  await _loadDirectory();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDirectory() async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      if (_currentPath.isEmpty) {
        _currentPath = await _fileSystem.getDocumentsDirectory();
      }

      _items = await _fileSystem.listDirectory(_currentPath);

      // Load Git status for files in this directory
      await _loadGitStatus();

      // Restore expanded state
      if (_expandedItems.containsKey(_currentPath)) {
        final cachedItems = _expandedItems[_currentPath]!;
        for (var item in _items) {
          final cachedItem = cachedItems.firstWhere(
            (cached) => cached.path == item.path,
            orElse: () => item,
          );
          item.isExpanded = cachedItem.isExpanded;
        }
      }

      widget.onDirectoryChanged?.call(_currentPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading directory: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGitStatus() async {
    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(_currentPath);
      if (!isGitRepo) {
        _logger.info('Not a Git repository: $_currentPath');
        return;
      }

      // Get Git status
      final gitStatus = await _gitService.getStatus(_currentPath);
      _logger.info(
        'Git status loaded: ${gitStatus.staged.length} staged, ${gitStatus.unstaged.length} unstaged, ${gitStatus.untracked.length} untracked',
      );

      // Update items with Git status
      for (var item in _items) {
        if (item.type == FileSystemItemType.file) {
          final relativePath = path.relative(item.path, from: _currentPath);

          if (gitStatus.staged.contains(relativePath)) {
            item.gitStatus = GitFileStatus.added;
            _logger.fine('File ${item.name} marked as ADDED');
          } else if (gitStatus.unstaged.contains(relativePath)) {
            item.gitStatus = GitFileStatus.modified;
            _logger.fine('File ${item.name} marked as MODIFIED');
          } else if (gitStatus.untracked.contains(relativePath)) {
            item.gitStatus = GitFileStatus.untracked;
            _logger.fine('File ${item.name} marked as UNTRACKED');
          } else {
            item.gitStatus = GitFileStatus.clean;
          }
        }
      }
    } catch (e) {
      // Silently handle Git status errors
      _logger.severe('Error loading Git status: $e');
    }
  }

  void _navigateTo(String path) async {
    if (_isLoading) return;

    setState(() {
      _currentPath = path;
      _selectedPath = null;
    });

    await _loadDirectory();
  }

  void _renameItem(FileSystemItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.name) {
                final newPath = path.join(path.dirname(item.path), newName);
                try {
                  await _fileSystem.rename(item.path, newPath);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadDirectory();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error renaming: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _selectItem(FileSystemItem item) {
    setState(() => _selectedPath = item.path);

    if (item.type == FileSystemItemType.file) {
      widget.onFileSelected?.call(item.path);
    }
  }

  void _showContextMenu(FileSystemItem item) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        if (item.type == FileSystemItemType.directory)
          const PopupMenuItem(value: 'new_file', child: Text('New File')),
        if (item.type == FileSystemItemType.directory)
          const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'open':
          _toggleExpand(item);
          break;
        case 'new_file':
          _createNewFile(item.path);
          break;
        case 'new_folder':
          _createNewFolder(item.path);
          break;
        case 'rename':
          _renameItem(item);
          break;
        case 'delete':
          _deleteItem(item);
          break;
      }
    });
  }

  void _toggleExpand(FileSystemItem item) {
    if (item.type == FileSystemItemType.directory) {
      setState(() {
        item.isExpanded = !item.isExpanded;
        // Save expanded state
        _expandedItems[_currentPath] = List.from(_items);
      });
    } else if (item.type == FileSystemItemType.file) {
      _selectItem(item);
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        _searchController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }
}
