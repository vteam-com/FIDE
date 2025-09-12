// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';

import '../../models/file_system_item.dart';

class OutlinePanel extends StatefulWidget {
  const OutlinePanel({super.key, required this.file, this.onOutlineUpdate});

  final FileSystemItem file;

  final Function(VoidCallback)? onOutlineUpdate;

  @override
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
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
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'OUTLINE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
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
      ),
    );
  }

  void refreshOutline() {
    _parseFile();
  }

  Widget _buildOutlineNode(OutlineNode node) {
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

    return InkWell(
      onTap: () {
        // TODO: Navigate to the corresponding line in the editor
      },
      hoverColor: Colors.blue.withOpacity(0.1),
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
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
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
        final visitor = _OutlineVisitor();
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
  final int level;

  OutlineNode({
    required this.name,
    required this.type,
    required this.line,
    this.level = 0,
  });
}

class _OutlineVisitor extends RecursiveAstVisitor<void> {
  final List<OutlineNode> nodes = [];
  int _currentLevel = 0;

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
    // Calculate line number from offset (approximate)
    final line = name.split('\n').length;
    nodes.add(
      OutlineNode(name: name, type: type, line: line, level: _currentLevel),
    );
  }
}
