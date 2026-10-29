import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_parser.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `OutlinePanel`.
class OutlinePanel extends ConsumerStatefulWidget {
  const OutlinePanel({
    super.key,
    required this.file,
    this.onOutlineUpdate,
    this.onNodeSelected,
    this.onJumpToLine,
  });

  final FileSystemItem file;

  final Function(int, int)? onNodeSelected;

  /// Opens a file at a 1-based line, for jumping to a caller.
  final Function(String, int)? onJumpToLine;

  final Function(VoidCallback)? onOutlineUpdate;

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  /// Last parsed text and its outline, per file.
  final Map<String, ({String content, List<OutlineNode> nodes})>
  _cachedOutlines = {};

  int _currentHighlightedLine = -1;

  /// Outline kinds that are Dart declarations, whose consumers are counted.
  static const Set<String> _countableTypes = {
    'class',
    'function',
    'method',
    'variable',
  };

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
    // Set up the callback for external updates
    if (widget.onOutlineUpdate != null) {
      widget.onOutlineUpdate!(() => refreshOutline());
    }
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
    final list = ListView.builder(
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
              const Center(child: CircularProgressIndicator())
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
                padding: EdgeInsets.all(AppSpacing.medium),
                child: Text('No outline available'),
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

  /// Handles `_OutlinePanelState.refreshOutline`.
  void refreshOutline() {
    _debouncedParseFile();
  }

  /// Builds a single outline tree node widget with icon, label, and cursor-based highlight.
  Widget _buildOutlineNode(OutlineNode node) {
    // Check if this node should be highlighted (cursor is on or near this line)
    final isHighlighted = _isNodeHighlighted(node);

    // Determine icon based on node type
    IconData iconData;
    Color iconColor;

    switch (node.type.toLowerCase()) {
      case 'class':
        iconData = Icons.class_;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'function':
        iconData = Icons.functions;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'method':
        iconData = Icons.functions;
        iconColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'variable':
        iconData = Icons.tag;
        iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'heading 1':
        iconData = Icons.looks_one;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'heading 2':
        iconData = Icons.looks_two;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'heading 3':
        iconData = Icons.looks_3;
        iconColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'heading 4':
        iconData = Icons.looks_4;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'heading 5':
        iconData = Icons.looks_5;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'heading 6':
        iconData = Icons.looks_6;
        iconColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'yaml key':
        iconData = Icons.vpn_key;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      default:
        iconData = Icons.circle;
        iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      color: isHighlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: () {
          // Navigate to the corresponding line and column in the editor
          widget.onNodeSelected?.call(node.line, node.column);
          // Ensure focus is transferred to the editor
          // The editor will handle focus internally
        },
        hoverColor: Colors.blue,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xLarge * node.level,
            top: AppSpacing.micro,
            bottom: AppSpacing.micro,
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: AppIconSize.medium),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: isHighlighted ? FontWeight.w600 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (_isSameNode(node, _countedNode)) ...[
                _buildConsumerCount(node),
                if (!_isRenaming)
                  MoreMenuButton(
                    onPressed: (position) => _showNodeMenu(node, position),
                  ),
              ],
            ],
          ),
        ),
      ),
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
    showMenu<VoidCallback>(
      context: context,
      position: MoreMenuButton.menuPosition(position),
      items: [
        PopupMenuItem(
          value: () => _rename(node),
          child: const IconMenuRow(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename…',
          ),
        ),
        if (consumers != null && consumers.length == 1)
          PopupMenuItem(
            value: () => widget.onJumpToLine?.call(
              consumers.single.filePath,
              consumers.single.lineNumber,
            ),
            child: const IconMenuRow(
              icon: Icons.call_made,
              label: 'Jump to caller',
            ),
          ),
        if (consumers != null && consumers.isNotEmpty)
          PopupMenuItem(
            value: () => _showConsumers(node, consumers),
            child: const IconMenuRow(
              icon: Icons.manage_search,
              label: 'Show all callers',
            ),
          ),
      ],
    ).then((action) => action?.call());
  }

  /// The name [node] is used by: `Foo<T>` is used as `Foo`.
  static String _usedName(OutlineNode node) => node.name.split('<').first;

  /// Asks for a new name and renames [node] and its uses across the
  /// project, writing the files only when the result still compiles.
  Future<void> _rename(OutlineNode node) async {
    final finder = ref.read(referenceFinderProvider);
    if (finder == null) return;
    if (ref.read(openDocumentsProvider).documents.any((d) => d.isDirty)) {
      MessageBox.showError(context, 'Save your open files before renaming');
      return;
    }
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
      final files = await finder.rename(
        filePath: widget.file.path,
        line: node.line,
        column: node.column,
        newName: newName,
      );
      for (final MapEntry(key: path, value: content) in files.entries) {
        await File(path).writeAsString(content);
      }
      await ref.read(openDocumentsProvider.notifier).reload(files.keys);
      ref.read(savedFilesRevisionProvider.notifier).state++;
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
      refreshOutline();
    }
  }

  /// Lists [consumers], the uses of [node], in the left panel's Search tab.
  void _showConsumers(OutlineNode node, List<SearchResult> consumers) {
    ref.read(referenceSearchProvider.notifier).state = ReferenceSearch(
      name: _usedName(node),
      results: consumers,
    );
    ref.read(leftPanelVisibleProvider.notifier).state = true;
    ref.read(activeLeftPanelTabProvider.notifier).state = LeftPanelTab.search;
  }

  /// Whether [a] and [b] are the same outline entry, even across re-parses.
  static bool _isSameNode(OutlineNode? a, OutlineNode? b) =>
      a != null &&
      b != null &&
      a.name == b.name &&
      a.type == b.type &&
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
        widget.file.path.endsWith('.dart') &&
        _countableTypes.contains(selected.type) &&
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
    final openDocuments = ref.read(openDocumentsProvider);
    final index = openDocuments.indexOf(file.path);
    if (index != OpenDocuments.noActiveDocument) {
      return openDocuments.documents[index].content;
    }
    return file.readAsString();
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
