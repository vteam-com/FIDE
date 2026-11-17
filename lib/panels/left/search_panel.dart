import 'package:fide/models/editor_search.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/search_result_node.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/foldername_widget.dart' show FolderNameWidget;
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/search_replace_field.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:fide/widgets/tree_branch.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Search tab: finds text or references across the project at
/// [projectPath] and opens the matches in the editor.
class SearchPanel extends ConsumerStatefulWidget {
  /// The project searched.
  final String projectPath;

  /// Creates the panel for the project at [projectPath].
  const SearchPanel({super.key, required this.projectPath});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Replacement text for every match in the results.
  final TextEditingController _replaceController = TextEditingController();

  /// The text the shown results matched.
  String _resultsQuery = '';
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
    _replaceController.dispose();
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
      _resultsQuery = search.name;
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
      final libPath = ProjectPaths(widget.projectPath).libDir;
      final search = ref.read(projectSearchServiceProvider);
      final results = await search.search(
        libPath,
        query,
        caseSensitive: _matchCase,
        wholeWord: _wholeWord,
      );
      if (!mounted) return;
      setState(() {
        _resultsQuery = query;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderBar(
          child: SearchReplaceField(
            searchField: AppTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search in lib/',
              icon: Icons.search,
              clearable: true,
              onCleared: () => setState(() => _resultsTree = null),
              onSubmitted: (_) => _performSearch(),
            ),
            searchActions: [
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
            ],
            replaceController: _replaceController,
            onReplaceAll: _resultsTree == null ? null : _replaceAll,
          ),
        ),

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
    );
  }

  /// Replaces every match in the results, after confirming, then searches
  /// again. Open files are saved first, so their unsaved edits are
  /// replaced too.
  Future<void> _replaceAll() async {
    final tree = _resultsTree;
    if (tree == null) return;
    final query = _resultsQuery;
    final replacement = _replaceController.text;
    final filePaths = _filePaths(tree);
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Replace All',
      message:
          'Replace every "$query" with "$replacement" in '
          '${filePaths.length} file${filePaths.length == 1 ? '' : 's'}?',
      confirmLabel: 'Replace',
    );
    if (!confirmed || !mounted) return;

    try {
      var count = 0;
      final files = await ref.read(openDocumentsProvider.notifier).applyEdits(
        () async {
          final replaced = await ref
              .read(projectSearchServiceProvider)
              .replaceAll(
                filePaths,
                query,
                replacement,
                caseSensitive: _matchCase,
                wholeWord: _wholeWord,
              );
          count = replaced.count;
          return replaced.files;
        },
      );
      if (!mounted) return;
      MessageBox.showSuccess(
        context,
        EditorSearch.replacedMessage(count, fileCount: files.length),
      );
      _searchController.text = query;
      await _performSearch();
    } catch (e) {
      if (mounted) MessageBox.showError(context, 'Replace failed: $e');
    }
  }

  /// Paths of the files under results [node].
  static List<String> _filePaths(SearchResultNode node) => node.isDirectory
      ? [for (final child in node.children) ..._filePaths(child)]
      : [node.path];

  /// Builds the row for a results folder or file.
  Widget _buildSearchResultNode(SearchResultNode node) {
    return node.isDirectory
        ? _buildDirectoryResultNode(node)
        : _buildFileResultNode(node);
  }

  /// The folder [node] of the results, expanding to its results.
  Widget _buildDirectoryResultNode(SearchResultNode node) {
    final isExpanded = _expandedState[node.path] ?? false;
    return TreeBranch(
      header: FolderNameWidget(
        node: node.folderNode,
        isExpanded: isExpanded,
        onTap: () => setState(() => _expandedState[node.path] = !isExpanded),
      ),
      isExpanded: isExpanded,
      children: [
        for (final child in node.children) _buildSearchResultNode(child),
      ],
    );
  }

  /// The file [node] of the results, opening the file, over its matches.
  Widget _buildFileResultNode(SearchResultNode node) {
    return TreeBranch(
      header: TreeRow.filePath(
        node.path,
        rootPath: widget.projectPath,
        onTap: () => openFile(ref, node.path),
      ),
      isExpanded: true,
      children: [for (final match in node.matches) _buildMatchResult(match)],
    );
  }

  /// The line of [result], its match highlighted, opening the file there:
  /// a place in the code like every other.
  Widget _buildMatchResult(SearchResult result) {
    final line = result.lineContent;
    final indent = line.length - line.trimLeft().length;
    return LocationRow(
      icon: FileIconUtils.ofPath(result.filePath),
      name: line.trim(),
      match: TextRange(
        start: result.matchStart - indent,
        end: result.matchEnd - indent,
      ),
      path: result.filePath,
      line: result.lineNumber,
      rootPath: widget.projectPath,
      onTap: () => openFileAtLine(ref, result.filePath, result.lineNumber),
    );
  }
}
