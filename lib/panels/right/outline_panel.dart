import 'dart:io' as io;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// Represents `OutlinePanel`.
class OutlinePanel extends StatefulWidget {
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
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
  final Map<String, DateTime> _cachedFileModTimes = {};

  final Map<String, List<OutlineNode>> _cachedOutlines = {};

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

    // Set up cursor position change callback
    EditorScreen.onCursorPositionChanged = _onCursorPositionChanged;
  }

  @override
  void dispose() {
    // Clean up the callback
    if (EditorScreen.onCursorPositionChanged == _onCursorPositionChanged) {
      EditorScreen.onCursorPositionChanged = null;
    }
    super.dispose();
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
              Expanded(
                child: ListView.builder(
                  itemCount: _outlineNodes.length,
                  itemBuilder: (_ /*context*/, index) {
                    final node = _outlineNodes[index];
                    return _buildOutlineNode(node);
                  },
                ),
              )
            else
              Flexible(
                child: SizedBox(
                  height: AppSize.outlineFallbackHeight,
                  child: ListView.builder(
                    itemCount: _outlineNodes.length,
                    itemBuilder: (_ /*context*/, index) {
                      final node = _outlineNodes[index];
                      return _buildOutlineNode(node);
                    },
                  ),
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

  /// Parses the current file, updates [_outlineNodes], and stores results in the cache.
  Future<void> _parseFile() async {
    if (!mounted) return;

    // Check if we have cached data for this file
    final filePath = widget.file.path;
    final cachedNodes = _cachedOutlines[filePath];
    final cachedModTime = _cachedFileModTimes[filePath];

    if (cachedNodes != null) {
      try {
        final fileStat = await io.File(filePath).stat();
        if (cachedModTime == fileStat.modified) {
          // File hasn't changed, use cached data
          if (mounted) {
            setState(() {
              _outlineNodes = cachedNodes;
              _isLoading = false;
              _error = '';
            });
          }
          return;
        }
      } catch (_) {
        // If we can't stat the file, continue with parsing
      }
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      late List<OutlineNode> nodes;

      if (widget.file.path.endsWith('.dart')) {
        final result = parseFile(
          path: widget.file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
        final visitor = _OutlineVisitor(result.content);
        result.unit.visitChildren(visitor);
        nodes = visitor.nodes;

        // Cache the successful parse results
        if (mounted) {
          try {
            final fileStat = await io.File(filePath).stat();
            _cachedOutlines[filePath] = nodes;
            _cachedFileModTimes[filePath] = fileStat.modified;
          } catch (_) {
            // Silently fail if we can't cache
          }
        }

        setState(() {
          _outlineNodes = nodes;
        });
      } else if (widget.file.path.endsWith('.md')) {
        // Parse markdown file for headers
        final content = await widget.file.readAsString();
        final lines = content.split('\n');
        nodes = <OutlineNode>[];

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('#')) {
            final level = line.split(' ')[0].length;
            final title = line.substring(level).trim();
            nodes.add(
              OutlineNode(
                name: title,
                type:
                    'Heading ${level.clamp(1, AppMetric.markdownMaxHeadingLevel)}',
                line: i + 1,
                column: level + 1, // Position after the # characters
                level: level - 1,
              ),
            );
          }
        }

        // Cache the successful parse results
        if (mounted) {
          try {
            final fileStat = await io.File(filePath).stat();
            _cachedOutlines[filePath] = nodes;
            _cachedFileModTimes[filePath] = fileStat.modified;
          } catch (_) {
            // Silently fail if we can't cache
          }
        }

        setState(() {
          _outlineNodes = nodes;
        });
      } else if (widget.file.path.endsWith('.yaml') ||
          widget.file.path.endsWith('.yml')) {
        // Parse YAML file for top-level keys
        final content = await widget.file.readAsString();
        nodes = <OutlineNode>[];

        try {
          final yamlDoc = loadYaml(content);
          if (yamlDoc is Map) {
            int currentLine = 1;
            final lines = content.split('\n');
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
                // Check if this line contains a top-level key
                if (!line.startsWith(' ') &&
                    !line.startsWith('\t') &&
                    line.contains(':')) {
                  final key = line.split(':')[0].trim();
                  if (yamlDoc.containsKey(key)) {
                    nodes.add(
                      OutlineNode(
                        name: key,
                        type: 'YAML Key',
                        line: currentLine,
                        column: line.indexOf(key) + 1,
                        level: 0,
                      ),
                    );
                  }
                }
              }
              currentLine++;
            }
          }
        } catch (e) {
          // If YAML parsing fails, throw to be handled by main error handler
          throw Exception('Error parsing YAML: $e');
        }

        // Cache the successful parse results
        if (mounted) {
          try {
            final fileStat = await io.File(filePath).stat();
            _cachedOutlines[filePath] = nodes;
            _cachedFileModTimes[filePath] = fileStat.modified;
          } catch (_) {
            // Silently fail if we can't cache
          }
        }

        setState(() {
          _outlineNodes = nodes;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error parsing file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

/// Represents `OutlineNode`.
class OutlineNode {
  final String name;
  final String type;
  final int line;
  final int column;
  final int level;

  OutlineNode({
    required this.name,
    required this.type,
    required this.line,
    this.column = 1,
    this.level = 0,
  });
}

class _OutlineVisitor extends RecursiveAstVisitor<void> {
  final List<OutlineNode> nodes = [];
  final String fileContent;
  int _currentLevel = 0;

  _OutlineVisitor(this.fileContent);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addNode(node.namePart.toString(), 'class', node.offset, node.length);
    _currentLevel++;
    super.visitClassDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addNode(node.name.toString(), 'function', node.offset, node.length);
    _currentLevel++;
    super.visitFunctionDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addNode(node.name.toString(), 'method', node.offset, node.length);
    _currentLevel++;
    super.visitMethodDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_currentLevel == 0) {
      _addNode(node.name.toString(), 'variable', node.offset, node.length);
    }
    super.visitVariableDeclaration(node);
  }

  /// Converts a source [offset] to a 1-indexed line/column and appends an [OutlineNode] to [nodes].
  void _addNode(String name, String type, int offset, int _ /* length */) {
    // Calculate the actual line number and column from the offset
    int lineNumber = 1; // Lines are 1-indexed
    int lastNewlineIndex = -1;

    for (int i = 0; i < offset && i < fileContent.length; i++) {
      if (fileContent[i] == '\n') {
        lineNumber++;
        lastNewlineIndex = i;
      }
    }

    // Column is 1-indexed: characters from last newline to offset
    int column = offset - lastNewlineIndex; // This gives 1-indexed column

    nodes.add(
      OutlineNode(
        name: name,
        type: type,
        line: lineNumber,
        column: column,
        level: _currentLevel,
      ),
    );
  }
}
