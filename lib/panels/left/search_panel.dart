import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';

class SearchResult {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final int matchStart;
  final int matchEnd;

  SearchResult({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });
}

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

class SearchPanel extends ConsumerStatefulWidget {
  final String projectPath;
  final Function(FileSystemItem)? onFileSelected;
  final Function(String, int)? onJumpToLine;

  const SearchPanel({
    super.key,
    required this.projectPath,
    this.onFileSelected,
    this.onJumpToLine,
  });

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _matchCase = false;
  SearchResultNode? _resultsTree;
  bool _isSearching = false;
  final Map<String, bool> _expandedState = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _resultsTree = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _resultsTree = null;
    });

    try {
      final libPath = path.join(widget.projectPath, 'lib');
      final results = await _searchInDirectory(libPath, query, _matchCase);
      final tree = _buildResultsTree(results, libPath);
      setState(() {
        _resultsTree = tree;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      // Handle error - could show a snackbar
    }
  }

  Future<List<SearchResult>> _searchInDirectory(
    String dirPath,
    String query,
    bool matchCase,
  ) async {
    final results = <SearchResult>[];
    final directory = Directory(dirPath);

    if (!await directory.exists()) {
      return results;
    }

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final fileResults = await _searchInFile(entity.path, query, matchCase);
        results.addAll(fileResults);
      }
    }

    return results;
  }

  Future<List<SearchResult>> _searchInFile(
    String filePath,
    String query,
    bool matchCase,
  ) async {
    final results = <SearchResult>[];

    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final searchText = matchCase ? line : line.toLowerCase();
        final searchQuery = matchCase ? query : query.toLowerCase();

        int startIndex = 0;
        while ((startIndex = searchText.indexOf(searchQuery, startIndex)) !=
            -1) {
          results.add(
            SearchResult(
              filePath: filePath,
              lineNumber: i + 1,
              lineContent: line,
              matchStart: startIndex,
              matchEnd: startIndex + query.length,
            ),
          );
          startIndex += query.length;
        }
      }
    } catch (e) {
      // Skip files that can't be read
    }

    return results;
  }

  SearchResultNode? _buildResultsTree(
    List<SearchResult> results,
    String libPath,
  ) {
    if (results.isEmpty) return null;

    // Group results by file path
    final fileGroups = <String, List<SearchResult>>{};
    for (final result in results) {
      fileGroups.putIfAbsent(result.filePath, () => []).add(result);
    }

    // Create the lib directory node
    final libNode = SearchResultNode.directory('lib', libPath);

    // Build the tree structure
    final pathNodes = <String, SearchResultNode>{};
    pathNodes[libPath] = libNode;

    for (final filePath in fileGroups.keys) {
      final matches = fileGroups[filePath]!;
      final relativePath = path.relative(filePath, from: libPath);
      final pathParts = path.split(relativePath);

      String currentPath = libPath;
      SearchResultNode? currentNode = libNode;

      // Create directory nodes
      for (int i = 0; i < pathParts.length - 1; i++) {
        final part = pathParts[i];
        final partPath = path.join(currentPath, part);

        if (!pathNodes.containsKey(partPath)) {
          final dirNode = SearchResultNode.directory(part, partPath);
          pathNodes[partPath] = dirNode;

          if (currentNode != null) {
            currentNode.children.add(dirNode);
          }
        }

        currentNode = pathNodes[partPath];
        currentPath = partPath;
      }

      // Create file node
      final fileName = pathParts.last;
      final fileNode = SearchResultNode.file(fileName, filePath, matches);

      if (currentNode != null) {
        currentNode.children.add(fileNode);
      }
    }

    // Sort children alphabetically (directories first, then files)
    _sortTreeNode(libNode);

    return libNode;
  }

  void _sortTreeNode(SearchResultNode node) {
    node.children.sort((a, b) {
      // Directories before files
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      // Alphabetical by name
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Recursively sort children
    for (final child in node.children) {
      if (child is SearchResultNode) {
        _sortTreeNode(child);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search in lib/',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _resultsTree = null;
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 8),

          // Options
          Row(
            children: [
              Checkbox(
                value: _matchCase,
                onChanged: (value) {
                  setState(() {
                    _matchCase = value ?? false;
                  });
                  if (_searchController.text.isNotEmpty) {
                    _performSearch();
                  }
                },
              ),
              const Text('Match casing'),
            ],
          ),

          const SizedBox(height: 8),

          // Search button
          ElevatedButton(
            onPressed: _isSearching ? null : _performSearch,
            child: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Search'),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _resultsTree == null && !_isSearching
                ? const Center(child: Text('No results found'))
                : _resultsTree != null
                ? SingleChildScrollView(
                    child: Column(
                      children: _resultsTree!.children
                          .map((node) => _buildSearchResultNode(node))
                          .toList(),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultNode(ProjectNode node) {
    if (node is! SearchResultNode) {
      return const SizedBox();
    }

    if (node.isDirectory) {
      return _buildDirectoryResultNode(node);
    } else {
      return _buildFileResultNode(node);
    }
  }

  Widget _buildDirectoryResultNode(SearchResultNode node) {
    final isExpanded = _expandedState[node.path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedState[node.path] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map((child) => _buildSearchResultNode(child))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFileResultNode(SearchResultNode node) {
    final relativePath = path.relative(node.path, from: widget.projectPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File header
        GestureDetector(
          onTap: () {
            final file = File(node.path);
            final fileSystemItem = FileSystemItem.fromFileSystemEntity(file);
            widget.onFileSelected?.call(fileSystemItem);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    relativePath,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Match results
        Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: node.matches
                .map((match) => _buildMatchResult(match))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchResult(SearchResult result) {
    return GestureDetector(
      onTap: () {
        widget.onJumpToLine?.call(result.filePath, result.lineNumber);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
            // ignore: deprecated_member_use
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line ${result.lineNumber}',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: _buildHighlightedText(
                  result.lineContent,
                  result.matchStart,
                  result.matchEnd,
                ),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildHighlightedText(
    String text,
    int matchStart,
    int matchEnd,
  ) {
    final spans = <TextSpan>[];

    if (matchStart > 0) {
      spans.add(TextSpan(text: text.substring(0, matchStart)));
    }

    spans.add(
      TextSpan(
        text: text.substring(matchStart, matchEnd),
        style: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );

    if (matchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(matchEnd)));
    }

    return spans;
  }
}
