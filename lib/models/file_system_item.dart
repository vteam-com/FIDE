import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../utils/file_utils.dart';

enum FileSystemItemType { file, directory, drive, parent }

enum GitFileStatus {
  untracked, // ? - New file, not tracked by Git
  added, // A - Added to staging area
  modified, // M - Modified
  deleted, // D - Deleted
  renamed, // R - Renamed
  copied, // C - Copied
  updated, // U - Updated but unmerged
  ignored, // ! - Ignored
  clean, // No changes
}

class FileSystemItem {
  final String name;
  final String path;
  final FileSystemItemType type;
  final DateTime? modified;
  final int? size;
  final List<FileSystemItem>? children;
  bool isExpanded;
  GitFileStatus gitStatus;

  FileSystemItem({
    required this.name,
    required this.path,
    required this.type,
    this.modified,
    this.size,
    this.children,
    this.isExpanded = false,
    this.gitStatus = GitFileStatus.clean,
  });

  factory FileSystemItem.fromFileSystemEntity(FileSystemEntity entity) {
    try {
      final stat = entity.statSync();
      final isDirectory = FileSystemEntity.isDirectorySync(entity.path);
      final isFile = FileSystemEntity.isFileSync(entity.path);

      return FileSystemItem(
        name: p.basename(entity.path),
        path: entity.path,
        type: isDirectory
            ? FileSystemItemType.directory
            : FileSystemItemType.file,
        modified: stat.modified,
        size: isFile ? stat.size : null,
      );
    } catch (e) {
      // Handle cases where statSync fails (e.g., large files, permission issues)
      final isDirectory = FileSystemEntity.isDirectorySync(entity.path);

      return FileSystemItem(
        name: p.basename(entity.path),
        path: entity.path,
        type: isDirectory
            ? FileSystemItemType.directory
            : FileSystemItemType.file,
        modified: null,
        size: null, // Don't load size for problematic files
      );
    }
  }

  // Create a parent directory item (for navigation)
  factory FileSystemItem.parentDirectory(String currentPath) {
    final parentPath = p.dirname(currentPath);
    return FileSystemItem(
      name: '..',
      path: parentPath,
      type: FileSystemItemType.parent,
    );
  }

  // Create a minimal file item for MRU loading (avoids file system calls)
  factory FileSystemItem.forMruLoading(String filePath) {
    return FileSystemItem(
      name: p.basename(filePath),
      path: filePath,
      type: FileSystemItemType.file,
      modified: null,
      size: null,
    );
  }

  // Get file extension for icons
  String get fileExtension {
    if (type != FileSystemItemType.file) return '';
    final ext = p.extension(p.basename(path));
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  // Check if the item is a code file
  bool get isCodeFile {
    if (type != FileSystemItemType.file) return false;
    final ext = fileExtension.toLowerCase();
    return const [
      'dart',
      'yaml',
      'json',
      'xml',
      'html',
      'css',
      'js',
    ].contains(ext);
  }

  // Toggle expanded state
  void toggleExpanded() {
    if (type == FileSystemItemType.directory) {
      isExpanded = !isExpanded;
    }
  }

  // Read file content as string
  Future<String> readAsString() async {
    if (type != FileSystemItemType.file) {
      throw Exception('Cannot read content of a directory');
    }
    final file = File(path);
    return await FileUtils.readFileContentSafely(file);
  }

  // Get file extension for filtering
  String get extension {
    if (type != FileSystemItemType.file) return '';
    final ext = p.extension(name).toLowerCase();
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  // Check if file is supported for outline view
  bool get isSupportedForOutline {
    if (type != FileSystemItemType.file) return false;
    final ext = extension;
    return const [
      'dart',
      'md',
      'markdown',
      'yaml',
      'yml',
      'json',
    ].contains(ext);
  }

  // Get color for Git status
  Color getGitStatusColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (gitStatus) {
      case GitFileStatus.added:
        return Colors.green; // 🟩 Green
      case GitFileStatus.modified:
        return Colors.blue; // 🟦 Blue
      case GitFileStatus.deleted:
        return Colors.red; // 🟥 Red
      case GitFileStatus.untracked:
        return isDark ? Colors.grey[600]! : Colors.grey[400]!; // ⚪️ Gray
      case GitFileStatus.ignored:
        return isDark ? Colors.grey[700]! : Colors.grey[500]!; // Gray italic
      default:
        return Theme.of(context).colorScheme.onSurface; // Default color
    }
  }

  // Get badge text for Git status
  String getGitStatusBadge() {
    switch (gitStatus) {
      case GitFileStatus.modified:
        return '●'; // Dot for modified
      case GitFileStatus.added:
        return '＋'; // Plus for added
      case GitFileStatus.deleted:
        return '−'; // Minus for deleted
      case GitFileStatus.untracked:
        return '?'; // Question mark for untracked
      case GitFileStatus.ignored:
        return '!'; // Exclamation for ignored
      default:
        return '';
    }
  }

  // Get text style for Git status
  TextStyle getGitStatusTextStyle(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    switch (gitStatus) {
      case GitFileStatus.deleted:
        return baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: getGitStatusColor(context),
        );
      case GitFileStatus.ignored:
        return baseStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: getGitStatusColor(context),
        );
      case GitFileStatus.untracked:
      case GitFileStatus.added:
      case GitFileStatus.modified:
        return baseStyle.copyWith(color: getGitStatusColor(context));
      default:
        return baseStyle;
    }
  }

  // Check if item has Git status changes
  bool get hasGitChanges => gitStatus != GitFileStatus.clean;
}
