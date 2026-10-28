import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum ProjectNodeType { file, directory }

enum LoadChildrenResult { success, accessDenied, fileSystemError, unknownError }

/// A node in the project file-tree, representing a file or directory with
/// optional Git status and lazy-loaded children.
///
/// Plain data; `ProjectTreeReader` fills in children from the file system.
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

  /// [children] with duplicate paths collapsed, keeping the last entry;
  /// incremental watcher updates can briefly add the same path twice.
  Iterable<ProjectNode> get uniqueChildren {
    return {for (final child in children) child.path: child}.values;
  }

  /// Returns `isDirectory`.
  bool get isDirectory => type == ProjectNodeType.directory;

  /// Returns `isFile`.
  bool get isFile => type == ProjectNodeType.file;

  /// Replaces [children] with [nodes] and records a successful load.
  void replaceChildren(Iterable<ProjectNode> nodes) {
    children
      ..clear()
      ..addAll(nodes);
    loadResult = LoadChildrenResult.success;
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
