import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

// Utils
import '../utils/message_helper.dart';

class DiffLine {
  final String content;
  final DiffLineType type;
  final int? oldLineNumber;
  final int? newLineNumber;

  DiffLine({
    required this.content,
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

enum DiffLineType { header, context, addition, deletion, hunkHeader }

class DiffViewer extends StatefulWidget {
  final String diffText;
  final String fileName;
  final VoidCallback? onClose;

  const DiffViewer({
    super.key,
    required this.diffText,
    required this.fileName,
    this.onClose,
  });

  @override
  State<DiffViewer> createState() => _DiffViewerState();
}

class _DiffViewerState extends State<DiffViewer> {
  final Logger _logger = Logger('DiffViewer');
  final ScrollController _scrollController = ScrollController();
  List<DiffLine> _diffLines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseDiff();
  }

  @override
  void didUpdateWidget(DiffViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diffText != widget.diffText) {
      _parseDiff();
    }
  }

  void _parseDiff() {
    setState(() => _isLoading = true);

    try {
      final lines = widget.diffText.split('\n');
      final parsedLines = <DiffLine>[];
      int oldLineNumber = 0;
      int newLineNumber = 0;

      for (final line in lines) {
        if (line.startsWith('diff --git')) {
          parsedLines.add(DiffLine(content: line, type: DiffLineType.header));
        } else if (line.startsWith('index ') ||
            line.startsWith('--- ') ||
            line.startsWith('+++ ')) {
          parsedLines.add(DiffLine(content: line, type: DiffLineType.header));
        } else if (line.startsWith('@@')) {
          // Hunk header: @@ -oldStart,oldCount +newStart,newCount @@
          parsedLines.add(
            DiffLine(content: line, type: DiffLineType.hunkHeader),
          );

          // Parse line numbers from hunk header
          final hunkMatch = RegExp(
            r'@@ -(\d+),\d+ \+(\d+),\d+ @@',
          ).firstMatch(line);
          if (hunkMatch != null) {
            oldLineNumber = int.parse(hunkMatch.group(1)!) - 1;
            newLineNumber = int.parse(hunkMatch.group(1)!) - 1;
          }
        } else if (line.startsWith('+')) {
          newLineNumber++;
          parsedLines.add(
            DiffLine(
              content: line.substring(1),
              type: DiffLineType.addition,
              oldLineNumber: null,
              newLineNumber: newLineNumber,
            ),
          );
        } else if (line.startsWith('-')) {
          oldLineNumber++;
          parsedLines.add(
            DiffLine(
              content: line.substring(1),
              type: DiffLineType.deletion,
              oldLineNumber: oldLineNumber,
              newLineNumber: null,
            ),
          );
        } else if (line.startsWith(' ')) {
          oldLineNumber++;
          newLineNumber++;
          parsedLines.add(
            DiffLine(
              content: line.substring(1),
              type: DiffLineType.context,
              oldLineNumber: oldLineNumber,
              newLineNumber: newLineNumber,
            ),
          );
        } else if (line.isNotEmpty) {
          parsedLines.add(DiffLine(content: line, type: DiffLineType.context));
        }
      }

      setState(() {
        _diffLines = parsedLines;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error parsing diff: $e');
      setState(() {
        _diffLines = [
          DiffLine(
            content: 'Error parsing diff: $e',
            type: DiffLineType.context,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  Color _getLineColor(DiffLineType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case DiffLineType.addition:
        return isDark ? Colors.green[900]! : Colors.green[50]!;
      case DiffLineType.deletion:
        return isDark ? Colors.red[900]! : Colors.red[50]!;
      case DiffLineType.hunkHeader:
        return isDark ? Colors.blue[900]! : Colors.blue[50]!;
      case DiffLineType.header:
        return isDark ? Colors.grey[800]! : Colors.grey[100]!;
      default:
        return Colors.transparent;
    }
  }

  Color _getLineNumberColor(DiffLineType type) {
    switch (type) {
      case DiffLineType.addition:
        return Colors.green;
      case DiffLineType.deletion:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLine(DiffLine line, int index) {
    final lineColor = _getLineColor(line.type);
    final lineNumberColor = _getLineNumberColor(line.type);

    return Container(
      color: lineColor,
      child: Row(
        children: [
          // Old line number
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              line.oldLineNumber?.toString() ?? '',
              style: TextStyle(
                color: lineNumberColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // New line number
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              line.newLineNumber?.toString() ?? '',
              style: TextStyle(
                color: lineNumberColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Line prefix (+, -, space)
          Container(
            width: 20,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              _getLinePrefix(line.type),
              style: TextStyle(
                color: lineNumberColor,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Line content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line.content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: _getTextColor(line.type),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLinePrefix(DiffLineType type) {
    switch (type) {
      case DiffLineType.addition:
        return '+';
      case DiffLineType.deletion:
        return '-';
      case DiffLineType.hunkHeader:
        return '@@';
      default:
        return '';
    }
  }

  Color _getTextColor(DiffLineType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case DiffLineType.addition:
        return isDark ? Colors.green[300]! : Colors.green[800]!;
      case DiffLineType.deletion:
        return isDark ? Colors.red[300]! : Colors.red[800]!;
      case DiffLineType.hunkHeader:
        return isDark ? Colors.blue[300]! : Colors.blue[800]!;
      case DiffLineType.header:
        return isDark ? Colors.grey[400]! : Colors.grey[600]!;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Diff: ${widget.fileName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.diffText));
              MessageHelper.showSuccess(context, 'Diff copied to clipboard');
            },
            tooltip: 'Copy diff',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Close',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _diffLines.isEmpty
          ? const Center(child: Text('No changes to display'))
          : Column(
              children: [
                // Header with line number labels
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Old',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'New',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Text(
                        'Content',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Diff content
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _diffLines.length,
                    itemBuilder: (context, index) {
                      return _buildLine(_diffLines[index], index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
