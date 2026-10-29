import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_parser.dart';
import 'package:fide/providers/ui_state_providers.dart';
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
  });

  final FileSystemItem file;

  final Function(int, int)? onNodeSelected;

  final Function(VoidCallback)? onOutlineUpdate;

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  /// Last parsed text and its outline, per file.
  final Map<String, ({String content, List<OutlineNode> nodes})>
  _cachedOutlines = {};

  int _currentHighlightedLine = -1;

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
            ],
          ),
        ),
      ),
    );
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
