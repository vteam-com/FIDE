import 'dart:io';
import 'dart:isolate';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/search_result_node.dart';
import 'package:fide/models/tree_order.dart';
import 'package:path/path.dart' as p;

/// The matches of a project search: the first [results] found, up to the
/// search's limit, the [files] holding a match, and how many matches
/// there are in [total], shown or not.
typedef ProjectSearchHits = ({
  List<SearchResult> results,
  List<String> files,
  int total,
});

/// Searches the files of a folder tree for text, line by line.
class ProjectSearchService {
  /// Creates a stateless search service.
  const ProjectSearchService();

  /// No match at all.
  static const ProjectSearchHits _none = (results: [], files: [], total: 0);

  /// The matches of [query] in the files under [directoryPath], in no
  /// particular file order: the first [limit] of them as results, every
  /// file holding one and their count. Unreadable files, and the tool
  /// output and hidden folders [ProjectFiles] leaves out, are skipped.
  ///
  /// The files are read and scanned on a background isolate, so a large
  /// project doesn't freeze the window.
  /// Searches each of [directories] in turn, as [search] does, merging the
  /// hits: at most [limit] of them shown, the rest only counted.
  Future<ProjectSearchHits> searchFolders(
    List<String> directories,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    int limit = AppMetric.projectSearchMaxResults,
  }) async {
    final results = <SearchResult>[];
    final files = <String>[];
    var total = 0;
    for (final directory in directories) {
      final hits = await search(
        directory,
        query,
        caseSensitive: caseSensitive,
        wholeWord: wholeWord,
        limit: limit - results.length,
      );
      results.addAll(hits.results);
      files.addAll(hits.files);
      total += hits.total;
    }
    return (results: results, files: files, total: total);
  }

  /// The matches of [query] in the files under [directoryPath], at most
  /// [limit] shown and the rest only counted; [caseSensitive] and
  /// [wholeWord] narrow them.
  Future<ProjectSearchHits> search(
    String directoryPath,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    int limit = AppMetric.projectSearchMaxResults,
  }) async {
    if (query.isEmpty) return _none;
    return Isolate.run(
      () => _scan(directoryPath, query, caseSensitive, wholeWord, limit),
    );
  }

  /// Runs [search] on the calling isolate.
  static Future<ProjectSearchHits> _scan(
    String directoryPath,
    String query,
    bool caseSensitive,
    bool wholeWord,
    int limit,
  ) async {
    if (!await Directory(directoryPath).exists()) return _none;

    final results = <SearchResult>[];
    final files = <String>[];
    var total = 0;
    await for (final entity in ProjectFiles.walk(directoryPath)) {
      final String content;
      try {
        content = await entity.readAsString();
      } on FileSystemException {
        continue;
      }
      final totalBefore = total;
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final start in EditorSearch.findMatches(
          lines[i],
          query,
          caseSensitive: caseSensitive,
          wholeWord: wholeWord,
        )) {
          total++;
          // Past the limit the matches are only counted
          if (results.length >= limit) continue;
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
      if (total > totalBefore) files.add(entity.path);
    }
    return (results: results, files: files, total: total);
  }

  /// The new content of each of [filePaths] with every match of [query]
  /// replaced by [replacement], and how many were replaced; files without
  /// a match are left out. [contents] overrides the text on disk, such as
  /// unsaved editor edits; unreadable files are skipped.
  Future<({Map<String, String> files, int count})> replaceAll(
    Iterable<String> filePaths,
    String query,
    String replacement, {
    bool caseSensitive = false,
    bool wholeWord = false,
    Map<String, String> contents = const {},
  }) async {
    final files = <String, String>{};
    var count = 0;
    for (final filePath in filePaths) {
      final String content;
      try {
        content = contents[filePath] ?? await File(filePath).readAsString();
      } on FileSystemException {
        continue;
      }
      final replaced = EditorSearch.replaceAll(
        content,
        query,
        replacement,
        caseSensitive: caseSensitive,
        wholeWord: wholeWord,
      );
      if (replaced.count == 0) continue;
      files[filePath] = replaced.text;
      count += replaced.count;
    }
    return (files: files, count: count);
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
