import 'dart:io';
import 'package:path/path.dart' as p;

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

  ProjectNode({
    required this.name,
    required this.path,
    required this.type,
    this.isExpanded = false,
    List<ProjectNode>? children,
  }) : children = children ?? [],
       fileExtension = type == ProjectNodeType.file
           ? p.extension(name).toLowerCase()
           : null;

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
        // Skip hidden files and directories
        if (!p.basename(entity.path).startsWith('.')) {
          children.add(await ProjectNode.fromFileSystemEntity(entity));
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
}
