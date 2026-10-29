import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/tree_order.dart';
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

  /// Inserts [child] at its place in tree order (for incremental updates).
  void addChild(ProjectNode child) {
    final index = children.indexWhere(
      (current) => compareInTree(child, current) < 0,
    );
    children.insert(index == -1 ? children.length : index, child);
  }

  /// Orders [a] and [b] as project trees list them.
  static int compareInTree(ProjectNode a, ProjectNode b) {
    return TreeOrder.compare(a.isDirectory, a.name, b.isDirectory, b.name);
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
