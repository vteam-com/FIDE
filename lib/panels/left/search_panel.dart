import 'package:fide/constants/constants.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/search_result_node.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/search_result_row.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/foldername_widget.dart' show FolderNameWidget;
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/search_replace_field.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:fide/widgets/tree_list_view.dart';
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

  /// Every file holding a match, listed or past the results' limit:
  /// the files Replace All changes.
  List<String> _matchingFiles = const [];

  /// Matches found past [AppMetric.projectSearchMaxResults], counted but
  /// not listed.
  int _unlistedCount = 0;

  bool _isSearching = false;
  final Map<String, bool> _expandedState = {};

  /// Counts the searches started, so a slow one finishing after a newer
  /// one, or after the results were cleared, shows nothing.
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Searches requested before this tab was built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  /// Drops the results, and those of any search still running.
  void _clearResults() {
    _searchGeneration++;
    setState(() {
      _resultsTree = null;
      _isSearching = false;
    });
  }

  /// Searches lib/ for the query typed, showing the matches once found,
  /// unless a newer search or a clear came meanwhile.
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearResults();
      return;
    }

    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _resultsTree = null;
    });

    try {
      final libPath = ProjectPaths(widget.projectPath).libDir;
      final search = ref.read(projectSearchServiceProvider);
      final hits = await search.search(
        libPath,
        query,
        caseSensitive: _matchCase,
        wholeWord: _wholeWord,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _resultsQuery = query;
        _resultsTree = search.toTree(hits.results, libPath);
        _matchingFiles = hits.files;
        _unlistedCount = hits.total - hits.results.length;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onCleared: _clearResults,
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
          child: switch (_resultsTree) {
            final tree? => _buildResults(tree),
            null when _isSearching => const LoadingIndicator(),
            null => const EmptyState(message: 'No results found'),
          },
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
    final filePaths = _matchingFiles;
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

  /// The results [tree], built a screenful at a time: its folders, its
  /// files each over its matches, then how many matches are not listed.
  Widget _buildResults(SearchResultNode tree) {
    final rows = TreeListView.flatten<Object>(
      [
        ...tree.children,
        // The count of unlisted matches is the last row
        if (_unlistedCount > 0) _unlistedCount,
      ],
      childrenOf: (node) => switch (node) {
        // A file always shows its matches
        SearchResultNode(isDirectory: false, :final matches) => matches,
        final SearchResultNode folder when _isExpanded(folder) =>
          folder.children,
        _ => const [],
      },
    );
    return TreeListView<Object>(
      rows: rows,
      rowBuilder: (_, node) => switch (node) {
        final SearchResultNode folder when folder.isDirectory =>
          _buildDirectoryResultNode(folder),
        final SearchResultNode file => _buildFileResultNode(file),
        final SearchResult match => SearchResultRow(
          result: match,
          rootPath: widget.projectPath,
        ),
        _ => _buildUnlistedCount(),
      },
    );
  }

  /// Whether the results folder [node] is open.
  bool _isExpanded(SearchResultNode node) => _expandedState[node.path] ?? false;

  /// The folder [node] of the results, expanding to its results.
  Widget _buildDirectoryResultNode(SearchResultNode node) {
    final isExpanded = _isExpanded(node);
    return FolderNameWidget(
      node: node.folderNode,
      isExpanded: isExpanded,
      onTap: () => setState(() => _expandedState[node.path] = !isExpanded),
    );
  }

  /// The file [node] of the results, opening the file; its matches follow
  /// in rows of their own.
  Widget _buildFileResultNode(SearchResultNode node) {
    return TreeRow.filePath(
      node.path,
      rootPath: widget.projectPath,
      onTap: () => openFile(ref, node.path),
    );
  }

  /// The line telling how many matches past the limit are not listed.
  Widget _buildUnlistedCount() {
    return Padding(
      padding: AppPadding.listItem,
      child: EmptyLabel(
        '${_unlistedCount.localized} more not listed; '
        'narrow the search to see them',
      ),
    );
  }
}
