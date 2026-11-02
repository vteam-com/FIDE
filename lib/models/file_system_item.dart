import 'package:fide/models/git_file_status.dart';
import 'package:fide/models/project_node.dart';
import 'package:path/path.dart' as p;

export 'package:fide/models/git_file_status.dart';

/// A file or directory shown and selected in the explorer panels.
///
/// Plain data built from values: the tree reader stats the disk, and
/// [FileSystemItem.fromNode] copies what it read.
class FileSystemItem {
  /// The entry's name, without its directory.
  final String name;

  /// The entry's full path.
  final String path;

  /// A note shown under the name, e.g. a design warning; null for none.
  final String? warning;

  /// Whether the entry is a file or a directory.
  final ProjectNodeType type;

  /// When the entry was last modified; null when not read.
  final DateTime? modified;

  /// The file's size in bytes; null for directories and when not read.
  final int? size;

  /// The entry's state in Git.
  final GitFileStatus gitStatus;

  /// Creates an item from its values.
  const FileSystemItem({
    required this.name,
    required this.path,
    required this.type,
    this.modified,
    this.size,
    this.gitStatus = GitFileStatus.clean,
    this.warning,
  });

  /// An item from [filePath] alone, without reading the disk: no date or
  /// size; a file unless [isDirectory].
  factory FileSystemItem.fromPath(
    String filePath, {
    bool isDirectory = false,
    GitFileStatus gitStatus = GitFileStatus.clean,
  }) {
    return FileSystemItem(
      name: p.basename(filePath),
      path: filePath,
      type: isDirectory ? ProjectNodeType.directory : ProjectNodeType.file,
      gitStatus: gitStatus,
    );
  }

  /// The item for a project-tree [node]: its type, date, size and Git
  /// status, with an optional [warning] shown under its name.
  factory FileSystemItem.fromNode(ProjectNode node, {String? warning}) {
    return FileSystemItem(
      name: node.name,
      path: node.path,
      type: node.type,
      modified: node.modified,
      size: node.size,
      gitStatus: node.gitStatus,
      warning: warning,
    );
  }

  /// Whether this item is a directory.
  bool get isDirectory => type == ProjectNodeType.directory;
}
