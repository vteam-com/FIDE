import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/outline_parser.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/outline_kind_style.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `OutlinePanel`.
class OutlinePanel extends ConsumerStatefulWidget {
  /// Creates the outline of [file].
  const OutlinePanel({super.key, required this.file});

  /// The file outlined; its editor text when open, else its saved text.
  final FileSystemItem file;

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  /// Last parsed text and its outline, per file.
  final Map<String, ({String content, List<OutlineNode> nodes})>
  _cachedOutlines = {};

  int _currentHighlightedLine = -1;

  /// The selected entry whose consumers are shown, if any.
  OutlineNode? _countedNode;

  /// Uses of [_countedNode]; null while they are being found.
  List<SearchResult>? _consumers;

  /// Bumped per lookup so a stale answer is dropped.
  int _consumersGeneration = 0;

  /// Whether [_countedNode] is being renamed.
  bool _isRenaming = false;

  static const Duration _debounceDuration = Duration(milliseconds: 150);

  Future<void>? _debouncingParse;

  String _error = '';

  bool _isCancelled = false;

  bool _isDebouncing = false;

  bool _isLoading = true;

  List<OutlineNode> _outlineNodes = [];

  @override
  void initState() {
    super.initState();
    _parseFile();
  }

  @override
  void didUpdateWidget(OutlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _countedNode = null;
      _consumersGeneration++;
      _debouncedParseFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      editorCursorLineProvider,
      (_, line) => _onCursorPositionChanged(line),
    );
    // Re-outline as the file is edited
    ref.listen<String?>(
      openDocumentsProvider.select(
        (documents) => _openContentOf(documents, widget.file.path),
      ),
      (_, _) => _debouncedParseFile(),
    );
    final list = ListView.builder(
      padding: AppPadding.panelContent,
      itemCount: _outlineNodes.length,
      itemBuilder: (_, index) => _buildOutlineNode(_outlineNodes[index]),
    );

    return LayoutBuilder(
      builder: (_ /*context*/, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const LoadingIndicator()
            else if (_error.isNotEmpty)
              OutputPanel(
                title: 'Parse Error',
                text: _error,
                isExpanded: true,
                onClear: () {
                  setState(() {
                    _error = '';
                    _parseFile(); // Retry parsing
                  });
                },
              )
            else if (_outlineNodes.isEmpty)
              const Padding(
                padding: AppPadding.panelContent,
                child: EmptyState(message: 'No outline available'),
              )
            else if (isConstrained)
              Expanded(child: list)
            else
              Flexible(
                child: SizedBox(
                  height: AppSize.outlineFallbackHeight,
                  child: list,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds a single outline tree node widget with icon, label, and cursor-based highlight.
  Widget _buildOutlineNode(OutlineNode node) {
    // Check if this node should be highlighted (cursor is on or near this line)
    final isHighlighted = _isNodeHighlighted(node);

    final kind = node.kind;
    return TreeRow(
      icon: Icon(
        kind.icon,
        color: kind.colorIn(Theme.of(context).colorScheme),
        size: AppIconSize.medium,
      ),
      name: node.name,
      depth: node.level,
      highlighted: isHighlighted,
      // Navigate to the corresponding line and column in the editor
      onTap: () => ref
          .read(activeEditorProvider)
          .navigateToLine(node.line, column: node.column),
      trailing: [
        if (_isSameNode(node, _countedNode)) ...[
          _buildConsumerCount(node),
          if (!_isRenaming)
            MoreMenuButton(
              onPressed: (position) => _showNodeMenu(node, position),
            ),
        ],
      ],
    );
  }

  /// [node]'s consumer count, clickable to list them in the Search panel,
  /// or a spinner while they are found.
  Widget _buildConsumerCount(OutlineNode node) {
    final consumers = _consumers;
    if (consumers == null || _isRenaming) {
      return const InlineSpinner(size: AppSize.compactProgressIndicator);
    }
    return ContainerCounter(
      count: consumers.length,
      tooltip: consumers.length == 1
          ? '1 consumer; click to list it in Search'
          : '${consumers.length} consumers; click to list them in Search',
      onTap: () => _showConsumers(node, consumers),
    );
  }

  /// [node]'s actions: Rename, and once its consumers are known, Jump to
  /// caller (when there is exactly one) and Show all callers.
  void _showNodeMenu(OutlineNode node, Offset position) {
    final consumers = _consumers;
    showActionMenu(context, position, [
      IconMenuItem(
        value: () => _rename(node),
        icon: Icons.drive_file_rename_outline,
        label: 'Rename…',
      ),
      if (consumers != null && consumers.length == 1)
        IconMenuItem(
          value: () => openFileAtLine(
            ref,
            consumers.single.filePath,
            consumers.single.lineNumber,
          ),
          icon: Icons.call_made,
          label: 'Jump to caller',
        ),
      if (consumers != null && consumers.isNotEmpty)
        IconMenuItem(
          value: () => _showConsumers(node, consumers),
          icon: Icons.manage_search,
          label: 'Show all callers',
        ),
    ]);
  }

  /// The name [node] is used by: `Foo<T>` is used as `Foo`.
  static String _usedName(OutlineNode node) => node.name.split('<').first;

  /// Asks for a new name and renames [node] and its uses across the
  /// project, after saving the open files, writing the files only when the
  /// result still compiles.
  Future<void> _rename(OutlineNode node) async {
    final finder = ref.read(referenceFinderProvider);
    if (finder == null) return;
    final name = _usedName(node);
    final newName = await MessageBox.promptForText(
      context,
      title: 'Rename $name',
      labelText: 'New name',
      hintText: 'Enter the new name',
      confirmLabel: 'Rename',
      initialText: name,
    );
    if (!mounted || newName == null || newName.isEmpty || newName == name) {
      return;
    }

    setState(() => _isRenaming = true);
    try {
      final files = await ref
          .read(openDocumentsProvider.notifier)
          .applyEdits(
            () => finder.rename(
              filePath: widget.file.path,
              line: node.line,
              column: node.column,
              newName: newName,
            ),
          );
      if (!mounted) return;
      MessageBox.showSuccess(
        context,
        files.length == 1
            ? 'Renamed $name to $newName'
            : 'Renamed $name to $newName in ${files.length} files',
      );
    } catch (e) {
      if (mounted) MessageBox.showError(context, 'Rename failed: $e');
    } finally {
      if (mounted) setState(() => _isRenaming = false);
      _debouncedParseFile();
    }
  }

  /// Lists [consumers], the uses of [node], in the left panel's Search tab.
  void _showConsumers(OutlineNode node, List<SearchResult> consumers) {
    ref.read(referenceSearchProvider.notifier).state = ReferenceSearch(
      name: _usedName(node),
      results: consumers,
    );
    showLeftPanelTab(ref.read, LeftPanelTab.search);
  }

  /// Whether [a] and [b] are the same outline entry, even across re-parses.
  static bool _isSameNode(OutlineNode? a, OutlineNode? b) =>
      a != null &&
      b != null &&
      a.name == b.name &&
      a.kind == b.kind &&
      a.line == b.line &&
      a.column == b.column;

  /// Finds the consumers of the innermost entry under the cursor, unless
  /// they are already shown.
  void _updateConsumers() {
    final selected = _outlineNodes.where(_isNodeHighlighted).lastOrNull;
    if (_isSameNode(selected, _countedNode)) return;
    final finder = ref.read(referenceFinderProvider);
    final countable =
        selected != null &&
        finder != null &&
        selected.kind.isCountable &&
        // Overrides are reached through the overridden member
        !selected.isOverride;
    final generation = ++_consumersGeneration;
    setState(() {
      _countedNode = countable ? selected : null;
      _consumers = null;
    });
    if (!countable) return;

    finder
        .find(
          filePath: widget.file.path,
          line: selected.line,
          column: selected.column,
        )
        .then((uses) {
          if (!mounted || generation != _consumersGeneration) return;
          setState(() => _consumers = uses);
        })
        .catchError((Object _) {
          // No count when the code can't be analyzed
          if (!mounted || generation != _consumersGeneration) return;
          setState(() => _countedNode = null);
        });
  }

  /// Triggers a debounced parse, cancelling any in-flight parse before scheduling a new one.
  void _debouncedParseFile() {
    if (_isDebouncing) {
      // Mark cancellation flag and allow previous future to complete naturally
      _isCancelled = true;
      // Wait for the previous operation to finish, then start new one
      _debouncingParse = _debouncingParse
          ?.then((_) {
            if (_isCancelled) {
              _isCancelled = false;
              return;
            }
            // If not cancelled, start new parsing operation
            _startDebouncedParse();
          })
          .catchError((_) {
            // If previous operation failed, start new one anyway
            _startDebouncedParse();
          });
    } else {
      // Start new parsing operation immediately
      _startDebouncedParse();
    }
  }

  /// Returns `true` when the cursor's current line falls on or within the given node's range.
  bool _isNodeHighlighted(OutlineNode node) {
    if (_currentHighlightedLine == -1) return false;

    // Check if cursor is on the exact line of this node
    if (_currentHighlightedLine == node.line) return true;

    // For broader highlighting, check if cursor is within the node's range
    // Find the next node at the same level or higher to determine the range
    final nodeIndex = _outlineNodes.indexOf(node);
    if (nodeIndex == -1) return false;

    int endLine = _currentHighlightedLine; // Default to current line

    // Find the next node that would end this node's scope
    for (int i = nodeIndex + 1; i < _outlineNodes.length; i++) {
      final nextNode = _outlineNodes[i];
      if (nextNode.level <= node.level) {
        endLine = nextNode.line - 1;
        break;
      }
    }

    // Check if cursor is within this node's range
    return _currentHighlightedLine >= node.line &&
        _currentHighlightedLine <= endLine;
  }

  void _onCursorPositionChanged(int lineNumber) {
    if (mounted) {
      setState(() {
        _currentHighlightedLine = lineNumber;
      });
      _updateConsumers();
    }
  }

  /// The text to outline: the editor's, unsaved edits included, when the
  /// file is open there, otherwise what is on disk.
  Future<String> _contentOf(FileSystemItem file) async {
    return _openContentOf(ref.read(openDocumentsProvider), file.path) ??
        ref.read(fileContentReaderProvider).read(file.path);
  }

  /// The editor's text for [filePath] among [openDocuments], or null when
  /// it isn't open.
  static String? _openContentOf(OpenDocuments openDocuments, String filePath) {
    final index = openDocuments.indexOf(filePath);
    if (index == OpenDocuments.noActiveDocument) return null;
    return openDocuments.documents[index].content;
  }

  /// Outlines the current file into [_outlineNodes], reusing the last
  /// outline when its text hasn't changed.
  Future<void> _parseFile() async {
    if (!mounted) return;

    final file = widget.file;
    final parser = OutlineParser.forFile(file.path);
    if (parser == null) {
      setState(() {
        _outlineNodes = [];
        _isLoading = false;
        _error = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final content = await _contentOf(file);
      final cached = _cachedOutlines[file.path];
      final nodes = cached != null && cached.content == content
          ? cached.nodes
          : parser.parse(content);
      _cachedOutlines[file.path] = (content: content, nodes: nodes);
      if (mounted && file.path == widget.file.path) {
        setState(() => _outlineNodes = nodes);
        _updateConsumers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error parsing file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Starts the debounce timer, initiating a new parse after [_debounceDuration] elapses.
  void _startDebouncedParse() {
    _isDebouncing = true;
    _debouncingParse = Future.delayed(_debounceDuration, () {
      if (mounted && !_isCancelled) {
        _parseFile();
      }
      _isDebouncing = false;
      _isCancelled = false; // Reset cancellation flag
    });
  }
}
