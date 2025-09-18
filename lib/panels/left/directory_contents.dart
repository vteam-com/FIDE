// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../../services/file_system_service.dart';
import '../../services/git_service.dart';
import '../../models/file_system_item.dart';

class DirectoryContents extends StatefulWidget {
  const DirectoryContents({
    super.key,
    required this.path,
    this.onFileSelected,
    this.selectedPath,
    this.onItemSelected,
  });

  final ValueChanged<String>? onFileSelected;
  final ValueChanged<String>? onItemSelected;
  final String path;
  final String? selectedPath;

  @override
  DirectoryContentsState createState() => DirectoryContentsState();
}

class DirectoryContentsState extends State<DirectoryContents> {
  final FileSystemService _fileSystem = FileSystemService();

  final GitService _gitService = GitService();

  final bool _isExpanded = true;

  bool _isLoading = false;

  List<FileSystemItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(left: 16.0),
        child: LinearProgressIndicator(),
      );
    }

    if (!_isExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _items.map((item) {
        final isSelected = widget.selectedPath == item.path;
        final isDirectory = item.type == FileSystemItemType.directory;

        // Get Git status styling
        final gitTextStyle = item.getGitStatusTextStyle(context);
        final badgeText = item.getGitStatusBadge();

        return Column(
          children: [
            ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isDirectory ? const Icon(Icons.folder) : _getFileIcon(item),
                  if (badgeText.isNotEmpty && !isDirectory)
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
              onTap: () {
                if (isDirectory) {
                  setState(() => item.isExpanded = !item.isExpanded);
                } else {
                  widget.onFileSelected?.call(item.path);
                  widget.onItemSelected?.call(item.path);
                }
              },
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
                  selectedPath: widget.selectedPath,
                  onItemSelected: widget.onItemSelected,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Future<String?> _findGitRoot(String startPath) async {
    String currentPath = startPath;

    while (currentPath != path.dirname(currentPath)) {
      if (await _gitService.isGitRepository(currentPath)) {
        return currentPath;
      }
      currentPath = path.dirname(currentPath);
    }

    return null;
  }

  Widget _getFileIcon(FileSystemItem item) {
    if (item.isCodeFile) {
      return const Icon(Icons.code);
    }
    switch (item.fileExtension.toLowerCase()) {
      case 'dart':
        return const Icon(Icons.developer_mode);
      case 'yaml':
      case 'yml':
        return const Icon(Icons.settings_applications);
      case 'json':
        return const Icon(Icons.data_object);
      case 'md':
      case 'markdown':
        return const Icon(Icons.text_snippet);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
        return const Icon(Icons.image);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  Future<void> _loadDirectory() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      _items = await _fileSystem.listDirectory(widget.path);

      // Load Git status for files in this directory
      await _loadGitStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGitStatus() async {
    try {
      // Find the root Git directory by walking up the path
      String? gitRoot = await _findGitRoot(widget.path);
      if (gitRoot == null) return;

      // Get Git status
      final gitStatus = await _gitService.getStatus(gitRoot);

      // Update items with Git status
      for (var item in _items) {
        if (item.type == FileSystemItemType.file) {
          final relativePath = path.relative(item.path, from: gitRoot);

          if (gitStatus.staged.contains(relativePath)) {
            item.gitStatus = GitFileStatus.added;
          } else if (gitStatus.unstaged.contains(relativePath)) {
            item.gitStatus = GitFileStatus.modified;
          } else if (gitStatus.untracked.contains(relativePath)) {
            item.gitStatus = GitFileStatus.untracked;
          } else {
            item.gitStatus = GitFileStatus.clean;
          }
        }
      }
    } catch (e) {
      // Silently handle Git status errors
      debugPrint('Error loading Git status: $e');
    }
  }
}
