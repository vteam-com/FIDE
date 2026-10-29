// ignore_for_file: deprecated_member_use

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:fide/constants/constants.dart';
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
          color: Theme.of(context).colorScheme.outline
              .withValues(alpha: AppOpacity.divider),
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
                _buildHeaderLabel(context, 'Original'),
                Container(
                  width: AppSize.borderThin,
                  height: AppSize.diffHeaderDividerHeight,
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: AppOpacity.divider),
                ),
                _buildHeaderLabel(context, 'Modified'),
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
                      _buildSide(
                        context,
                        line.oldLine,
                        line.oldContent,
                        line.type == DiffType.deletion
                            ? Colors.red[AppShade.strong]
                            : null,
                      ),
                      // Divider
                      Container(
                        width: AppSize.borderThin,
                        height: AppSize.diffRowDividerHeight,
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: AppOpacity.divider),
                      ),
                      _buildSide(
                        context,
                        line.newLine,
                        line.newContent,
                        line.type == DiffType.addition
                            ? Colors.green[AppShade.strong]
                            : null,
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

  /// The bold title above one side of the diff.
  Widget _buildHeaderLabel(BuildContext context, String label) {
    return Expanded(
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface
              .withValues(alpha: AppOpacity.secondaryText),
        ),
      ),
    );
  }

  /// One side of a diff row: the dimmed [lineNumber], then [content] in
  /// [contentColor], or the theme's text color when null.
  Widget _buildSide(
    BuildContext context,
    String lineNumber,
    String content,
    Color? contentColor,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final style = AppTextStyle.monospace.copyWith(
      fontSize: AppFontSize.caption,
    );
    return Expanded(
      child: Container(
        padding: AppPadding.diffRow,
        child: Row(
          children: [
            SizedBox(
              width: AppSize.diffLineNumberWidth,
              child: Text(
                lineNumber,
                style: style.copyWith(
                  color: onSurface.withValues(alpha: AppOpacity.disabled),
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                content,
                style: style.copyWith(color: contentColor ?? onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum DiffType { equal, addition, deletion }
