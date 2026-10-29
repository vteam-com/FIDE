import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:path/path.dart' as p;

/// Reads directories from the file system into [ProjectNode] trees.
///
/// Children are listed hidden entries included, directories first, each
/// group sorted case-insensitively. The sync variants are for isolates.
class ProjectTreeReader {
  /// Creates a stateless reader.
  const ProjectTreeReader();

  /// Loads [node]'s immediate children.
  Future<LoadChildrenResult> loadChildren(ProjectNode node) {
    return _load(node, recursive: false);
  }

  /// Loads [node]'s whole subtree.
  Future<LoadChildrenResult> loadTree(ProjectNode node) {
    return _load(node, recursive: true);
  }

  /// Synchronous [loadTree], for use inside isolates.
  void loadTreeSync(ProjectNode node) {
    if (!node.isDirectory) return;

    try {
      node.replaceChildren(
        _sortedNodes([
          for (final entity in Directory(node.path).listSync())
            (entity, entity.statSync()),
        ]),
      );
      for (final child in node.children.where((child) => child.isDirectory)) {
        loadTreeSync(child);
      }
    } catch (e) {
      node.loadResult = _classifyLoadError(e);
    }
  }

  /// Creates an unloaded node for [entity], reading its type from disk.
  Future<ProjectNode> nodeFor(FileSystemEntity entity) async {
    return _fromStat(entity, await entity.stat());
  }

  /// Synchronous [nodeFor], for use inside isolates.
  ProjectNode nodeForSync(FileSystemEntity entity) {
    return _fromStat(entity, entity.statSync());
  }

  /// Loads [node]'s children and optionally recurses into subdirectories.
  Future<LoadChildrenResult> _load(
    ProjectNode node, {
    required bool recursive,
  }) async {
    if (!node.isDirectory) return LoadChildrenResult.success;

    try {
      // Async stat calls avoid blocking the UI isolate
      final entries = <(FileSystemEntity, FileStat)>[];
      await for (final entity in Directory(node.path).list()) {
        entries.add((entity, await entity.stat()));
      }
      node.replaceChildren(_sortedNodes(entries));

      if (recursive) {
        for (final child in node.children.where((c) => c.isDirectory)) {
          await loadTree(child);
        }
      }
      return LoadChildrenResult.success;
    } catch (e) {
      return node.loadResult = _classifyLoadError(e);
    }
  }

  /// Maps an enumeration failure to the result shown to the user.
  static LoadChildrenResult _classifyLoadError(Object error) {
    if (error is PathAccessException ||
        error.toString().contains('Operation not permitted')) {
      return LoadChildrenResult.accessDenied;
    }
    if (error is FileSystemException) {
      return LoadChildrenResult.fileSystemError;
    }
    return LoadChildrenResult.unknownError;
  }

  /// Builds an unexpanded node for [entity] from an already-read [stat].
  static ProjectNode _fromStat(FileSystemEntity entity, FileStat stat) {
    return ProjectNode(
      name: p.basename(entity.path),
      path: entity.path,
      type: stat.type == FileSystemEntityType.directory
          ? ProjectNodeType.directory
          : ProjectNodeType.file,
    );
  }

  /// Nodes for [entries], directories first, then by name ignoring case.
  static List<ProjectNode> _sortedNodes(
    List<(FileSystemEntity, FileStat)> entries,
  ) {
    return [for (final (entity, stat) in entries) _fromStat(entity, stat)]
      ..sort(ProjectNode.compareInTree);
  }
}
