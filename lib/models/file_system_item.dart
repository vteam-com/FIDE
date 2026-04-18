// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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

/// Shared display helpers for Git status values.
extension GitFileStatusDisplay on GitFileStatus {
  /// Returns the badge symbol for this Git status.
  String badgeSymbol({String deletedSymbol = '-'}) {
    switch (this) {
      case GitFileStatus.modified:
        return '●';
      case GitFileStatus.added:
        return '+';
      case GitFileStatus.deleted:
        return deletedSymbol;
      case GitFileStatus.untracked:
        return '?';
      case GitFileStatus.ignored:
        return '!';
      default:
        return '';
    }
  }
}

/// A node in the file-system tree used by the explorer panels, representing a file or directory.
class FileSystemItem {
  final String name;
  final String path;
  final String? warning;
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
    this.warning,
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
  /// Returns `fileExtension`.
  String get fileExtension {
    if (type != FileSystemItemType.file) return '';
    final basename = p.basename(path);

    // Handle dotfiles (files starting with .)
    if (basename.startsWith('.') && basename.length > 1) {
      final secondDotIndex = basename.indexOf('.', 1);
      if (secondDotIndex != -1) {
        // File like .gitignore, .dockerignore
        return basename.substring(1, secondDotIndex);
      } else {
        // File like .env, .bashrc
        return basename.substring(1);
      }
    }

    final ext = p.extension(basename);
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  static const int maxFileSize = 1 * 1024 * 1024; // 1MB
  static const String fileTooBigMessage = '// file too big to load';

  /// Check if file is within maximum file size limit
  static Future<bool> isWithinMaxFileSize(File file) async {
    final fileSize = await file.length();
    return fileSize <= maxFileSize;
  }

  /// Load file content with custom error message if too big
  static Future<String> fileToStringMaxSizeCheck(
    File file, {
    String tooBigMessage = fileTooBigMessage,
  }) async {
    if (!await isWithinMaxFileSize(file)) {
      return tooBigMessage;
    }
    return await file.readAsString();
  }

  // Read file content as string
  /// Handles `FileSystemItem.readAsString`.
  Future<String> readAsString() async {
    if (type != FileSystemItemType.file) {
      throw Exception('Cannot read content of a directory');
    }
    final file = File(path);
    return await fileToStringMaxSizeCheck(file);
  }

  // Get file extension for filtering
  /// Returns `extension`.
  String get extension {
    if (type != FileSystemItemType.file) return '';
    final ext = p.extension(name).toLowerCase();
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  // Check if file is supported for outline view
  /// Returns `isSupportedForOutline`.
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
  /// Handles `FileSystemItem.getGitStatusColor`.
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
        return isDark
            ? Colors.grey[AppShade.medium]!
            : Colors.grey[AppShade.mild]!; // ⚪️ Gray
      case GitFileStatus.ignored:
        return isDark
            ? Colors.grey[AppShade.strong]!
            : Colors.grey[AppShade.neutral]!; // Gray italic
      default:
        return Theme.of(context).colorScheme.onSurface; // Default color
    }
  }

  // Get badge text for Git status
  /// Handles `FileSystemItem.getGitStatusBadge`.
  String getGitStatusBadge() {
    return gitStatus.badgeSymbol();
  }

  // Get text style for Git status
  /// Handles `FileSystemItem.getGitStatusTextStyle`.
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
  /// Returns `hasGitChanges`.
  bool get hasGitChanges => gitStatus != GitFileStatus.clean;
}
