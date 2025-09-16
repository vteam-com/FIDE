import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:fide/models/file_system_item.dart';

enum ProjectNodeType { file, directory }

enum LoadChildrenResult { success, accessDenied, fileSystemError, unknownError }

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

  bool get isDirectory => type == ProjectNodeType.directory;
  bool get isFile => type == ProjectNodeType.file;

  // Create a ProjectNode from a FileSystemEntity
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

  // Load children for a directory node
  Future<LoadChildrenResult> loadChildren() async {
    if (!isDirectory) return LoadChildrenResult.success;

    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();

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
        children.add(await ProjectNode.fromFileSystemEntity(entity));
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

  // Find a node by path
  ProjectNode? findNode(String targetPath) {
    if (path == targetPath) return this;

    for (final child in children) {
      final found = child.findNode(targetPath);
      if (found != null) return found;
    }

    return null;
  }

  // Toggle expanded state
  void toggleExpanded() {
    isExpanded = !isExpanded;
  }

  // Get Git status color
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
        return Colors.grey[600]!;
      case GitFileStatus.clean:
      default:
        return colorScheme.onSurface;
    }
  }

  // Get Git status badge text
  String getGitStatusBadge() {
    switch (gitStatus) {
      case GitFileStatus.added:
        return '+';
      case GitFileStatus.modified:
        return '●';
      case GitFileStatus.deleted:
        return '−';
      case GitFileStatus.untracked:
        return '?';
      case GitFileStatus.ignored:
        return '!';
      case GitFileStatus.clean:
      default:
        return '';
    }
  }

  // Get Git status text style
  TextStyle getGitStatusTextStyle(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13,
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
          color: Colors.grey[600],
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
}
