// ignore_for_file: deprecated_member_use

import 'package:fide/widgets/filename_widget.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
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
  final Logger _logger = Logger('DirectoryContentsState');

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
      children: _items.map((FileSystemItem item) {
        final isSelected = widget.selectedPath == item.path;
        final isDirectory = item.type == FileSystemItemType.directory;

        return Column(
          children: [
            FileNameWidget(
              item: item,
              isSelected: isSelected,
              showExpansionIndicator: isDirectory,
              onTap: () {
                if (isDirectory) {
                  setState(() => item.isExpanded = !item.isExpanded);
                } else {
                  widget.onFileSelected?.call(item.path);
                  widget.onItemSelected?.call(item.path);
                }
              },
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
      _logger.severe('Error loading Git status: $e');
    }
  }
}
