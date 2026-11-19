import 'package:fide/models/git_file_status.dart';
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

  /// When the entry was last modified, as read with the tree; null when
  /// unknown.
  final DateTime? modified;

  /// The file's size in bytes, as read with the tree; null for directories
  /// and when unknown.
  final int? size;
  final List<ProjectNode> children;
  LoadChildrenResult? loadResult;
  final bool isHidden;
  GitFileStatus gitStatus;

  ProjectNode({
    required this.name,
    required this.path,
    required this.type,
    this.modified,
    this.size,
    List<ProjectNode>? children,
    this.gitStatus = GitFileStatus.clean,
  }) : children = children ?? [],
       isHidden = name.startsWith('.');

  /// The path name of a folder's parent.
  static const String _parentFolder = '..';

  /// [children] with duplicate paths collapsed, keeping the last entry;
  /// incremental watcher updates can briefly add the same path twice.
  Iterable<ProjectNode> get uniqueChildren {
    return {for (final child in children) child.path: child}.values;
  }

  /// Returns `isDirectory`.
  bool get isDirectory => type == ProjectNodeType.directory;

  /// Returns `isFile`.
  bool get isFile => type == ProjectNodeType.file;

  /// Whether this node's children were read; a folder left unread loads
  /// them when first expanded.
  bool get isLoaded => loadResult == LoadChildrenResult.success;

  /// Whether reading this node's children was attempted and failed.
  bool get hasLoadError =>
      loadResult != null && loadResult != LoadChildrenResult.success;

  /// The loaded child named [name]; null when there is none.
  ProjectNode? childNamed(String name) =>
      uniqueChildren.where((child) => child.name == name).firstOrNull;

  /// The loaded node at [relativePath], a path relative to this one; null
  /// when it isn't loaded or doesn't exist, or the path is absolute or
  /// leaves this node.
  ProjectNode? descendantAt(String relativePath) {
    final names = namesTo(relativePath);
    if (names == null) return null;
    ProjectNode? node = this;
    for (final name in names) {
      node = node?.childNamed(name);
    }
    return node;
  }

  /// The files of this node's loaded subtree, in tree order: this node
  /// when it is a file, else the files under its children, without going
  /// into the children [skip] leaves out.
  Iterable<ProjectNode> files({bool Function(ProjectNode child)? skip}) sync* {
    if (isFile) {
      yield this;
      return;
    }
    for (final child in uniqueChildren) {
      if (skip?.call(child) ?? false) continue;
      yield* child.files(skip: skip);
    }
  }

  /// The names leading from a node to the one at [relativePath] under it;
  /// null when the path is absolute or leaves the node.
  static List<String>? namesTo(String relativePath) {
    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized)) return null;
    final names = p.split(normalized);
    return names.first == _parentFolder ? null : names;
  }

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

  /// Inserts [child] at its place in tree order (for incremental updates),
  /// replacing the child already at its path, as when a file is saved
  /// atomically or a checkout recreates it.
  void addChild(ProjectNode child) {
    removeChild(child.path);
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
