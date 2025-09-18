// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';

import '../models/file_system_item.dart';
import 'editor_screen.dart';

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
  int _currentHighlightedLine = -1;

  String _error = '';

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
      _parseFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else if (_outlineNodes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No outline available'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _outlineNodes.length,
              itemBuilder: (context, index) {
                final node = _outlineNodes[index];
                return _buildOutlineNode(node);
              },
            ),
          ),
      ],
    );
  }

  void refreshOutline() {
    _parseFile();
  }

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
            left: 16.0 * node.level,
            top: 2.0,
            bottom: 2.0,
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 13,
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

  Future<void> _parseFile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      if (widget.file.path.endsWith('.dart')) {
        final result = parseFile(
          path: widget.file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
        final visitor = _OutlineVisitor(result.content);
        result.unit.visitChildren(visitor);
        setState(() {
          _outlineNodes = visitor.nodes;
        });
      } else if (widget.file.path.endsWith('.md')) {
        // Parse markdown file for headers
        final content = await widget.file.readAsString();
        final lines = content.split('\n');
        final nodes = <OutlineNode>[];

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('#')) {
            final level = line.split(' ')[0].length;
            final title = line.substring(level).trim();
            nodes.add(
              OutlineNode(
                name: title,
                type: 'Heading ${level.clamp(1, 6)}',
                line: i + 1,
                column: level + 1, // Position after the # characters
                level: level - 1,
              ),
            );
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
}

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
    _addNode(node.name.toString(), 'class', node.offset, node.length);
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

  void _addNode(String name, String type, int offset, int length) {
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
