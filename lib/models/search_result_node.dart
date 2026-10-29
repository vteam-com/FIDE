import 'package:fide/models/project_node.dart';
import 'package:fide/models/search_result.dart';

/// A folder or file in the search results tree.
///
/// Holds only what the results view shows, rather than extending
/// `ProjectNode`, whose file-system loading would replace the matches with
/// whatever is on disk.
class SearchResultNode {
  /// Last path segment.
  final String name;

  /// Absolute path.
  final String path;

  /// Whether this is a folder grouping deeper results.
  final bool isDirectory;

  /// Subfolders and files below a folder.
  final List<SearchResultNode> children;

  /// Matches in a file.
  final List<SearchResult> matches;

  /// Creates a folder node.
  SearchResultNode.directory(this.name, this.path)
    : isDirectory = true,
      children = [],
      matches = const [];

  /// This folder as a display-only `ProjectNode` for `FolderNameWidget`,
  /// carrying just the name, path and child count it shows.
  ProjectNode get folderNode => ProjectNode(
    name: name,
    path: path,
    type: ProjectNodeType.directory,
    children: [
      for (final child in children)
        ProjectNode(
          name: child.name,
          path: child.path,
          type: child.isDirectory
              ? ProjectNodeType.directory
              : ProjectNodeType.file,
        ),
    ],
  );

  /// Creates a file node holding its [matches].
  SearchResultNode.file(this.name, this.path, this.matches)
    : isDirectory = false,
      children = const [];
}
