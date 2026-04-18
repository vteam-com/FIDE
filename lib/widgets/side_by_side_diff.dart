// ignore_for_file: deprecated_member_use

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

part 'side_by_side_diff.diff_line.dart';

// Side-by-side diff widget
/// Represents `SideBySideDiff`.
class SideBySideDiff extends StatelessWidget {
  const SideBySideDiff({
    super.key,
    required this.oldText,
    required this.newText,
  });

  final String newText;

  final String oldText;

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
          color: Theme.of(
            context,
          ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
        ),
        borderRadius: BorderRadius.circular(AppRadius.tiny),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: AppPadding.diffHeader,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: AppOpacity.disabled),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.tiny),
                topRight: Radius.circular(AppRadius.tiny),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Original',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: AppOpacity.secondaryText,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: AppSize.borderThin,
                  height: AppSize.diffHeaderDividerHeight,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
                ),
                Expanded(
                  child: Text(
                    'Modified',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: AppOpacity.secondaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Diff content
          Expanded(
            child: ListView.builder(
              itemCount: diffLines.length,
              itemBuilder: (context, index) {
                final line = diffLines[index];
                return Container(
                  decoration: BoxDecoration(
                    color: line.type == DiffType.deletion
                        ? Colors.red.withValues(alpha: AppOpacity.subtle)
                        : line.type == DiffType.addition
                        ? Colors.green.withValues(alpha: AppOpacity.subtle)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Old side
                      Expanded(
                        child: Container(
                          padding: AppPadding.diffRow,
                          child: Row(
                            children: [
                              SizedBox(
                                width: AppSize.diffLineNumberWidth,
                                child: Text(
                                  line.oldLine,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: AppFontSize.caption,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: AppOpacity.disabled),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.medium),
                              Expanded(
                                child: Text(
                                  line.oldContent,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: AppFontSize.caption,
                                    color: line.type == DiffType.deletion
                                        ? Colors.red[AppShade.strong]
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
                        width: AppSize.borderThin,
                        height: AppSize.diffRowDividerHeight,
                        color: Theme.of(context).colorScheme.outline.withValues(
                          alpha: AppOpacity.divider,
                        ),
                      ),
                      // New side
                      Expanded(
                        child: Container(
                          padding: AppPadding.diffRow,
                          child: Row(
                            children: [
                              SizedBox(
                                width: AppSize.diffLineNumberWidth,
                                child: Text(
                                  line.newLine,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: AppFontSize.caption,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: AppOpacity.disabled),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.medium),
                              Expanded(
                                child: Text(
                                  line.newContent,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: AppFontSize.caption,
                                    color: line.type == DiffType.addition
                                        ? Colors.green[AppShade.strong]
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
