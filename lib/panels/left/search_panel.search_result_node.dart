part of 'search_panel.dart';

/// Represents `SearchResultNode`.
class SearchResultNode extends ProjectNode {
  final List<SearchResult> matches;

  SearchResultNode({
    required super.name,
    required super.path,
    required super.type,
    super.isExpanded = false,
    super.children,
    this.matches = const [],
  });

  factory SearchResultNode.directory(
    String name,
    String path, {
    List<ProjectNode>? children,
  }) {
    return SearchResultNode(
      name: name,
      path: path,
      type: ProjectNodeType.directory,
      children: children,
    );
  }

  factory SearchResultNode.file(
    String name,
    String path,
    List<SearchResult> matches,
  ) {
    return SearchResultNode(
      name: name,
      path: path,
      type: ProjectNodeType.file,
      matches: matches,
    );
  }
}
