import 'package:flutter/material.dart';
import '../services/file_system_service.dart';
import '../models/file_system_item.dart';

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

        return Column(
          children: [
            ListTile(
              leading: item.type == FileSystemItemType.directory
                  ? const Icon(Icons.folder)
                  : _getFileIcon(item),
              title: Text(
                item.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              trailing: item.type == FileSystemItemType.directory
                  ? Icon(
                      item.isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                    )
                  : null,
              onTap: () {
                if (item.type == FileSystemItemType.directory) {
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
            if (item.type == FileSystemItemType.directory && item.isExpanded)
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
}
