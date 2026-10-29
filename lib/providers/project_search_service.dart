import 'dart:io';

import 'package:fide/models/editor_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/search_result_node.dart';
import 'package:fide/models/tree_order.dart';
import 'package:path/path.dart' as p;

/// Searches the files of a folder tree for text, line by line.
class ProjectSearchService {
  /// Creates a stateless search service.
  const ProjectSearchService();

  /// Every match of [query] in the files under [directoryPath], in no
  /// particular file order; unreadable files are skipped.
  Future<List<SearchResult>> search(
    String directoryPath,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) async {
    final directory = Directory(directoryPath);
    if (query.isEmpty || !await directory.exists()) return const [];

    final results = <SearchResult>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final String content;
      try {
        content = await entity.readAsString();
      } on FileSystemException {
        continue;
      }
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final start in EditorSearch.findMatches(
          lines[i],
          query,
          caseSensitive: caseSensitive,
          wholeWord: wholeWord,
        )) {
          results.add(
            SearchResult(
              filePath: entity.path,
              lineNumber: i + 1,
              lineContent: lines[i],
              matchStart: start,
              matchEnd: start + query.length,
            ),
          );
        }
      }
    }
    return results;
  }

  /// Groups [results] into a folder tree rooted at [rootPath], in tree
  /// order; null when there are no results.
  SearchResultNode? toTree(List<SearchResult> results, String rootPath) {
    if (results.isEmpty) return null;

    final byFile = <String, List<SearchResult>>{};
    for (final result in results) {
      byFile.putIfAbsent(result.filePath, () => []).add(result);
    }

    final root = SearchResultNode.directory(p.basename(rootPath), rootPath);
    final folders = {rootPath: root};
    for (final MapEntry(key: filePath, value: matches) in byFile.entries) {
      final parts = p.split(p.relative(filePath, from: rootPath));
      var folder = root;
      for (final part in parts.take(parts.length - 1)) {
        final partPath = p.join(folder.path, part);
        folder = folders.putIfAbsent(partPath, () {
          final child = SearchResultNode.directory(part, partPath);
          folder.children.add(child);
          return child;
        });
      }
      folder.children.add(SearchResultNode.file(parts.last, filePath, matches));
    }
    _sort(root);
    return root;
  }

  /// Sorts folder [node]'s subtree into tree order.
  static void _sort(SearchResultNode node) {
    if (!node.isDirectory) return;
    node.children.sort(
      (a, b) => TreeOrder.compare(a.isDirectory, a.name, b.isDirectory, b.name),
    );
    node.children.forEach(_sort);
  }
}
