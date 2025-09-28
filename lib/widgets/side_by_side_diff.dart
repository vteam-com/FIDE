// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

// Side-by-side diff widget
class SideBySideDiff extends StatelessWidget {
  final String oldText;
  final String newText;

  const SideBySideDiff({
    super.key,
    required this.oldText,
    required this.newText,
  });

  @override
  Widget build(BuildContext context) {
    final List<DiffLine> diffLines = [];

    // Split texts into lines
    final oldLines = oldText.isEmpty ? <String>[] : oldText.split('\n');
    final newLines = newText.split('\n');

    // If old text is empty (new file), show all new lines as additions
    if (oldLines.isEmpty) {
      for (int i = 0; i < newLines.length; i++) {
        diffLines.add(
          DiffLine(
            oldLine: '',
            oldContent: '',
            newLine: '${i + 1}',
            newContent: newLines[i],
            type: DiffType.addition,
          ),
        );
      }
    } else {
      // Use diff_match_patch for proper diffing
      final dmp = DiffMatchPatch();
      final diffs = dmp.diff(oldText, newText);

      // Convert character-level diffs to line-level diffs
      int oldLineNum = 1;
      int newLineNum = 1;

      for (final diff in diffs) {
        final lines = diff.text.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];

          if (diff.operation == DIFF_DELETE) {
            if (line.isNotEmpty) {
              diffLines.add(
                DiffLine(
                  oldLine: '$oldLineNum',
                  oldContent: line,
                  newLine: '',
                  newContent: '',
                  type: DiffType.deletion,
                ),
              );
              oldLineNum++;
            }
          } else if (diff.operation == DIFF_INSERT) {
            if (line.isNotEmpty) {
              diffLines.add(
                DiffLine(
                  oldLine: '',
                  oldContent: '',
                  newLine: '$newLineNum',
                  newContent: line,
                  type: DiffType.addition,
                ),
              );
              newLineNum++;
            }
          } else if (diff.operation == DIFF_EQUAL) {
            if (line.isNotEmpty) {
              diffLines.add(
                DiffLine(
                  oldLine: '$oldLineNum',
                  oldContent: line,
                  newLine: '$newLineNum',
                  newContent: line,
                  type: DiffType.equal,
                ),
              );
              oldLineNum++;
              newLineNum++;
            }
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Original',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
                Expanded(
                  child: Text(
                    'Modified',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Diff content
          SizedBox(
            height: 400, // Fixed height for scrollable area
            child: ListView.builder(
              itemCount: diffLines.length,
              itemBuilder: (context, index) {
                final line = diffLines[index];
                return Container(
                  decoration: BoxDecoration(
                    color: line.type == DiffType.deletion
                        ? Colors.red.withOpacity(0.1)
                        : line.type == DiffType.addition
                        ? Colors.green.withOpacity(0.1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Old side
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  line.oldLine,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line.oldContent,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: line.type == DiffType.deletion
                                        ? Colors.red[700]
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        height: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                      ),
                      // New side
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  line.newLine,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line.newContent,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: line.type == DiffType.addition
                                        ? Colors.green[700]
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum DiffType { equal, addition, deletion }

class DiffLine {
  final String oldLine;
  final String oldContent;
  final String newLine;
  final String newContent;
  final DiffType type;

  DiffLine({
    required this.oldLine,
    required this.oldContent,
    required this.newLine,
    required this.newContent,
    required this.type,
  });
}
