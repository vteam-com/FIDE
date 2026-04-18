import 'dart:async';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum ProjectNodeType { file, directory }

enum LoadChildrenResult { success, accessDenied, fileSystemError, unknownError }

/// A node in the project file-tree, representing a file or directory with optional Git status and lazy-loaded children.
class ProjectNode {
  final String name;
  final String path;
  final ProjectNodeType type;
  bool isExpanded;
  final List<ProjectNode> children;
  final String? fileExtension;
  LoadChildrenResult? loadResult;
  final bool isHidden;
  GitFileStatus gitStatus;

  ProjectNode({
    required this.name,
    required this.path,
    required this.type,
    this.isExpanded = false,
    List<ProjectNode>? children,
    this.gitStatus = GitFileStatus.clean,
  }) : children = children ?? [],
       fileExtension = type == ProjectNodeType.file
           ? p.extension(name).toLowerCase()
           : null,
       isHidden = name.startsWith('.');

  /// Returns `isDirectory`.
  bool get isDirectory => type == ProjectNodeType.directory;

  /// Returns `isFile`.
  bool get isFile => type == ProjectNodeType.file;

  // Create a ProjectNode from a FileSystemEntity
  /// Handles `ProjectNode.fromFileSystemEntity`.
  static Future<ProjectNode> fromFileSystemEntity(
    FileSystemEntity entity,
  ) async {
    final stat = await entity.stat();
    final isDirectory = stat.type == FileSystemEntityType.directory;

    return ProjectNode(
      name: p.basename(entity.path),
      path: entity.path,
      type: isDirectory ? ProjectNodeType.directory : ProjectNodeType.file,
      isExpanded: false,
    );
  }

  // Enumerate contents for a directory node
  /// Handles `ProjectNode.enumerateContents`.
  Future<LoadChildrenResult> enumerateContents() async {
    return _enumerateContentsInternal(recursive: false);
  }

  // Recursively enumerate all contents for a directory node (background enumeration)
  /// Handles `ProjectNode.enumerateContentsRecursive`.
  Future<LoadChildrenResult> enumerateContentsRecursive() async {
    return _enumerateContentsInternal(recursive: true);
  }

  /// Loads this directory's children and optionally recurses into subdirectories.
  Future<LoadChildrenResult> _enumerateContentsInternal({
    required bool recursive,
  }) async {
    if (!isDirectory) return LoadChildrenResult.success;

    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();

      // Sort directories first, then files, both alphabetically
      // Use async stat calls to avoid blocking UI
      final stats = <FileSystemEntity, FileStat>{};
      for (final entity in entities) {
        stats[entity] = await entity.stat();
      }

      entities.sort((a, b) {
        final aStat = stats[a]!;
        final bStat = stats[b]!;

        if (aStat.type == bStat.type) {
          final aName = p.basename(a.path).toLowerCase();
          final bName = p.basename(b.path).toLowerCase();
          return aName.compareTo(bName);
        }

        return aStat.type == FileSystemEntityType.directory ? -1 : 1;
      });

      children.clear();
      for (final entity in entities) {
        // Include all files and directories, including hidden ones
        final childNode = await ProjectNode.fromFileSystemEntity(entity);
        children.add(childNode);

        // If it's a directory, recursively enumerate its contents
        if (recursive && childNode.isDirectory) {
          await childNode.enumerateContentsRecursive();
        }
      }
      loadResult = LoadChildrenResult.success;
      return LoadChildrenResult.success;
    } catch (e) {
      // Categorize the error for better user experience
      if (e is PathAccessException ||
          e.toString().contains('Operation not permitted')) {
        loadResult = LoadChildrenResult.accessDenied;
        return LoadChildrenResult.accessDenied;
      } else if (e is FileSystemException) {
        loadResult = LoadChildrenResult.fileSystemError;
        return LoadChildrenResult.fileSystemError;
      } else {
        loadResult = LoadChildrenResult.unknownError;
        return LoadChildrenResult.unknownError;
      }
    }
  }

  // Synchronous version for isolates (doesn't return a Future)
  /// Handles `ProjectNode.enumerateContentsRecursiveSync`.
  void enumerateContentsRecursiveSync() {
    if (!isDirectory) return;

    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = dir.listSync();

      // Sort directories first, then files, both alphabetically
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();

        if (aStat.type == bStat.type) {
          final aName = p.basename(a.path).toLowerCase();
          final bName = p.basename(b.path).toLowerCase();
          return aName.compareTo(bName);
        }

        return aStat.type == FileSystemEntityType.directory ? -1 : 1;
      });

      children.clear();
      for (final entity in entities) {
        // Include all files and directories, including hidden ones
        final childNode = fromFileSystemEntitySync(entity);
        children.add(childNode);

        // If it's a directory, recursively enumerate its contents
        if (childNode.isDirectory) {
          childNode.enumerateContentsRecursiveSync();
        }
      }
      loadResult = LoadChildrenResult.success;
    } catch (e) {
      // Categorize the error for better user experience
      if (e is PathAccessException ||
          e.toString().contains('Operation not permitted')) {
        loadResult = LoadChildrenResult.accessDenied;
      } else if (e is FileSystemException) {
        loadResult = LoadChildrenResult.fileSystemError;
      } else {
        loadResult = LoadChildrenResult.unknownError;
      }
    }
  }

  // Synchronous version of fromFileSystemEntity for isolates
  /// Handles `ProjectNode.fromFileSystemEntitySync`.
  static ProjectNode fromFileSystemEntitySync(FileSystemEntity entity) {
    final stat = entity.statSync();
    final isDirectory = stat.type == FileSystemEntityType.directory;

    return ProjectNode(
      name: p.basename(entity.path),
      path: entity.path,
      type: isDirectory ? ProjectNodeType.directory : ProjectNodeType.file,
      isExpanded: false,
    );
  }

  // Find a node by path
  /// Handles `ProjectNode.findNode`.
  ProjectNode? findNode(String targetPath) {
    if (path == targetPath) return this;

    for (final child in children) {
      final found = child.findNode(targetPath);
      if (found != null) return found;
    }

    return null;
  }

  // Get Git status color
  /// Handles `ProjectNode.getGitStatusColor`.
  Color getGitStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (gitStatus) {
      case GitFileStatus.added:
        return Colors.green;
      case GitFileStatus.modified:
        return Colors.blue;
      case GitFileStatus.deleted:
        return Colors.red;
      case GitFileStatus.untracked:
        return Colors.grey;
      case GitFileStatus.ignored:
        return Colors.grey[AppShade.medium]!;
      case GitFileStatus.clean:
      default:
        return colorScheme.onSurface;
    }
  }

  // Get Git status badge text
  /// Handles `ProjectNode.getGitStatusBadge`.
  String getGitStatusBadge() {
    return gitStatus.badgeSymbol(deletedSymbol: '−');
  }

  // Get Git status text style
  /// Handles `ProjectNode.getGitStatusTextStyle`.
  TextStyle getGitStatusTextStyle(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: AppFontSize.body,
      color: Theme.of(context).colorScheme.onSurface,
    );

    switch (gitStatus) {
      case GitFileStatus.deleted:
        return baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: Colors.red,
        );
      case GitFileStatus.ignored:
        return baseStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: Colors.grey[AppShade.medium],
        );
      case GitFileStatus.added:
        return baseStyle.copyWith(color: Colors.green);
      case GitFileStatus.modified:
        return baseStyle.copyWith(color: Colors.blue);
      case GitFileStatus.untracked:
        return baseStyle.copyWith(color: Colors.grey);
      case GitFileStatus.clean:
      default:
        return baseStyle;
    }
  }

  // Add a child node (for incremental updates)
  /// Handles `ProjectNode.addChild`.
  void addChild(ProjectNode child) {
    // Find the correct insertion position to maintain sorted order
    int insertIndex = 0;
    for (int i = 0; i < children.length; i++) {
      final current = children[i];

      // Directories come before files
      if (child.isDirectory && !current.isDirectory) {
        break;
      } else if (!child.isDirectory && current.isDirectory) {
        insertIndex = i;
        break;
      }

      // Same type: alphabetical order
      if (child.name.toLowerCase().compareTo(current.name.toLowerCase()) < 0) {
        break;
      }

      insertIndex = i + 1;
    }

    children.insert(insertIndex, child);
  }

  // Remove a child node by path (for incremental updates)
  /// Handles `ProjectNode.removeChild`.
  bool removeChild(String childPath) {
    final index = children.indexWhere((child) => child.path == childPath);
    if (index != -1) {
      children.removeAt(index);
      return true;
    }
    return false;
  }
}
