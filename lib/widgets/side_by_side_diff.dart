// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

// Side-by-side diff widget using diff_match_patch
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
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(oldText, newText);

    // Clean up the diffs
    dmp.diffCleanupSemantic(diffs);
    dmp.diffCleanupEfficiency(diffs);

    // Split into lines for side-by-side display
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    // Create line-by-line diff
    final List<DiffLine> diffLines = [];
    int oldIndex = 0;
    int newIndex = 0;

    for (final diff in diffs) {
      final lines = diff.text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty && i < lines.length - 1) {
          continue;
        } // Skip empty lines except last

        switch (diff.operation) {
          case DIFF_DELETE:
            if (oldIndex < oldLines.length) {
              diffLines.add(
                DiffLine(
                  oldLine: '${oldIndex + 1}',
                  oldContent: oldLines[oldIndex],
                  newLine: '',
                  newContent: '',
                  type: DiffType.deletion,
                ),
              );
              oldIndex++;
            }
            break;
          case DIFF_INSERT:
            if (newIndex < newLines.length) {
              diffLines.add(
                DiffLine(
                  oldLine: '',
                  oldContent: '',
                  newLine: '${newIndex + 1}',
                  newContent: newLines[newIndex],
                  type: DiffType.addition,
                ),
              );
              newIndex++;
            }
            break;
          case DIFF_EQUAL:
            if (oldIndex < oldLines.length && newIndex < newLines.length) {
              diffLines.add(
                DiffLine(
                  oldLine: '${oldIndex + 1}',
                  oldContent: oldLines[oldIndex],
                  newLine: '${newIndex + 1}',
                  newContent: newLines[newIndex],
                  type: DiffType.equal,
                ),
              );
              oldIndex++;
              newIndex++;
            }
            break;
        }
      }
    }

    // Add remaining lines
    while (oldIndex < oldLines.length || newIndex < newLines.length) {
      if (oldIndex < oldLines.length && newIndex < newLines.length) {
        diffLines.add(
          DiffLine(
            oldLine: '${oldIndex + 1}',
            oldContent: oldLines[oldIndex],
            newLine: '${newIndex + 1}',
            newContent: newLines[newIndex],
            type: DiffType.equal,
          ),
        );
      } else if (oldIndex < oldLines.length) {
        diffLines.add(
          DiffLine(
            oldLine: '${oldIndex + 1}',
            oldContent: oldLines[oldIndex],
            newLine: '',
            newContent: '',
            type: DiffType.deletion,
          ),
        );
      } else if (newIndex < newLines.length) {
        diffLines.add(
          DiffLine(
            oldLine: '',
            oldContent: '',
            newLine: '${newIndex + 1}',
            newContent: newLines[newIndex],
            type: DiffType.addition,
          ),
        );
      }
      oldIndex++;
      newIndex++;
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
