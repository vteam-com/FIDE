// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/constants/constants.dart';
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

  /// Color for names and badges with this status; the theme's text color
  /// for clean files.
  Color color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      GitFileStatus.added => Colors.green,
      GitFileStatus.modified => Colors.blue,
      GitFileStatus.deleted => Colors.red,
      GitFileStatus.untracked =>
        Colors.grey[isDark ? AppShade.medium : AppShade.mild]!,
      GitFileStatus.ignored =>
        Colors.grey[isDark ? AppShade.strong : AppShade.neutral]!,
      _ => Theme.of(context).colorScheme.onSurface,
    };
  }

  /// Small icon marking a folder with this status; null when unmarked.
  IconData? get icon => switch (this) {
    GitFileStatus.added => Icons.add_circle,
    GitFileStatus.modified => Icons.edit,
    GitFileStatus.deleted => Icons.remove_circle,
    GitFileStatus.untracked => Icons.new_releases,
    _ => null,
  };

  /// [base] styled for this status: colored, struck through when deleted,
  /// italic when ignored.
  TextStyle textStyle(BuildContext context, TextStyle base) {
    return switch (this) {
      GitFileStatus.deleted => base.copyWith(
        decoration: TextDecoration.lineThrough,
        color: color(context),
      ),
      GitFileStatus.ignored => base.copyWith(
        fontStyle: FontStyle.italic,
        color: color(context),
      ),
      GitFileStatus.untracked ||
      GitFileStatus.added ||
      GitFileStatus.modified => base.copyWith(color: color(context)),
      _ => base,
    };
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

  // Check if item has Git status changes
  /// Returns `hasGitChanges`.
  bool get hasGitChanges => gitStatus != GitFileStatus.clean;
}
