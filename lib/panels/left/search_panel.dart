import 'dart:io';

import 'package:fide/constants/constants.dart'
    show AppPadding, AppSpacing, AppIconSize, AppFontSize, AppTextStyle;
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/search_result_node.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/foldername_widget.dart' show FolderNameWidget;
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Represents `SearchPanel`.
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
  final FocusNode _searchFocusNode = FocusNode();
  bool _matchCase = false;
  bool _wholeWord = false;
  SearchResultNode? _resultsTree;
  bool _isSearching = false;
  final Map<String, bool> _expandedState = {};

  @override
  void initState() {
    super.initState();
    // Searches requested before this tab was built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(referenceSearchProvider);
      if (pending != null) _showReferences(pending);
      final query = ref.read(projectSearchRequestProvider);
      if (query != null) _startSearch(query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Shows [search]'s uses as the results, with every folder expanded.
  void _showReferences(ReferenceSearch search) {
    ref.read(referenceSearchProvider.notifier).state = null;
    _searchController.text = search.name;
    final tree = ref
        .read(projectSearchServiceProvider)
        .toTree(search.results, widget.projectPath);
    setState(() {
      _matchCase = true;
      _wholeWord = true;
      _isSearching = false;
      _resultsTree = tree;
      if (tree != null) _expandFolders(tree);
    });
  }

  /// Focuses the input with its text selected, first searching for [query]
  /// unless it is empty.
  void _startSearch(String query) {
    ref.read(projectSearchRequestProvider.notifier).state = null;
    if (query.isNotEmpty) {
      _searchController.text = query;
      _performSearch();
    }
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    _searchFocusNode.requestFocus();
  }

  /// Marks every folder under [node] expanded.
  void _expandFolders(SearchResultNode node) {
    if (!node.isDirectory) return;
    _expandedState[node.path] = true;
    node.children.forEach(_expandFolders);
  }

  /// Handles `_performSearch`.
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
      final libPath = p.join(widget.projectPath, 'lib');
      final search = ref.read(projectSearchServiceProvider);
      final results = await search.search(
        libPath,
        query,
        caseSensitive: _matchCase,
        wholeWord: _wholeWord,
      );
      if (!mounted) return;
      setState(() {
        _resultsTree = search.toTree(results, libPath);
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      // Handle error - could show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReferenceSearch?>(referenceSearchProvider, (_, next) {
      if (next != null) _showReferences(next);
    });
    ref.listen<String?>(projectSearchRequestProvider, (_, next) {
      if (next != null) _startSearch(next);
    });
    return Container(
      padding: AppPadding.panelContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          AppTextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: 'Search in lib/',
            icon: Icons.search,
            clearable: true,
            onCleared: () => setState(() => _resultsTree = null),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: AppSpacing.medium),

          // Options
          SearchToggleIcons(
            caseSensitive: _matchCase,
            wholeWord: _wholeWord,
            showWholeWord: true,
            onCaseSensitiveChanged: (value) {
              setState(() {
                _matchCase = value;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch();
              }
            },
            onWholeWordChanged: (value) {
              setState(() {
                _wholeWord = value;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch();
              }
            },
          ),

          Divider(),

          // Results
          Expanded(
            child: _resultsTree == null && !_isSearching
                ? const EmptyState(message: 'No results found')
                : _resultsTree != null
                ? SingleChildScrollView(
                    child: Column(
                      children: _resultsTree!.children
                          .map((node) => _buildSearchResultNode(node))
                          .toList(),
                    ),
                  )
                : const LoadingIndicator(),
          ),
        ],
      ),
    );
  }

  /// Builds the row for a results folder or file.
  Widget _buildSearchResultNode(SearchResultNode node) {
    if (node.isDirectory) {
      /// Handles `_buildDirectoryResultNode`.
      return _buildDirectoryResultNode(node);
    } else {
      /// Handles `_buildFileResultNode`.
      return _buildFileResultNode(node);
    }
  }

  /// Handles `_buildDirectoryResultNode`.
  Widget _buildDirectoryResultNode(SearchResultNode node) {
    final isExpanded = _expandedState[node.path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FolderNameWidget(
          node: node.folderNode,
          isExpanded: isExpanded,
          onTap: () {
            setState(() {
              _expandedState[node.path] = !isExpanded;
            });
          },
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xLarge),
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

  /// Handles `_buildFileResultNode`.
  Widget _buildFileResultNode(SearchResultNode node) {
    final relativePath = p.relative(node.path, from: widget.projectPath);
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File header
        TreeRow(
          icon: FileIconUtils.getFileIcon(item),
          name: relativePath,
          path: node.path,
          rootPath: widget.projectPath,
          onTap: () => widget.onFileSelected?.call(item),
        ),
        // Match results
        Padding(
          padding: const EdgeInsets.only(left: AppIconSize.xLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.tiny,
            children: node.matches
                .map((match) => _buildMatchResult(match))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Handles `_buildMatchResult`.
  Widget _buildMatchResult(SearchResult result) {
    return Clickable(
      onTap: () =>
          widget.onJumpToLine?.call(result.filePath, result.lineNumber),
      child: SurfaceCard(
        padding: SurfacePadding.dense,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line ${result.lineNumber}',
              style: TextStyle(
                fontSize: AppFontSize.badge,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            RichText(
              text: TextSpan(
                /// Handles `_buildHighlightedText`.
                children: _buildHighlightedText(
                  result.lineContent,
                  result.matchStart,
                  result.matchEnd,
                ),
                style: AppTextStyle.monospace.copyWith(
                  fontSize: AppFontSize.caption,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles `_buildHighlightedText`.
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
