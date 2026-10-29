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
/// Character code of the first encoded line; 0 is skipped because some
  /// tools treat the null character as a string terminator.
  static const int _firstLineCode = 1;
final String newText;
final String oldText;
@override
  Widget build(BuildContext context) {
    final diffLines = computeLines(oldText, newText);

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
/// Compares [oldText] and [newText] line by line and returns one row per
  /// unchanged, deleted or added line, numbered on each side.
  static List<DiffLine> computeLines(String oldText, String newText) {
    final oldLines = oldText.isEmpty ? <String>[] : oldText.split('\n');
    final newLines = newText.split('\n');

    // Encode each distinct line as one character so diff_match_patch
    // compares whole lines instead of the characters inside them.
    final codes = <String, int>{};
    String encode(List<String> lines) => String.fromCharCodes(
      lines.map(
        (line) => codes.putIfAbsent(line, () => codes.length + _firstLineCode),
      ),
    );
    final encodedOld = encode(oldLines);
    final encodedNew = encode(newLines);
    final linesByCode = {for (final e in codes.entries) e.value: e.key};

    final diffLines = <DiffLine>[];
    int oldLineNum = 1;
    int newLineNum = 1;
    for (final diff in DiffMatchPatch().diff(encodedOld, encodedNew)) {
      for (final code in diff.text.codeUnits) {
        final line = linesByCode[code]!;
        if (diff.operation == DIFF_DELETE) {
          diffLines.add(
            DiffLine(
              oldLine: '${oldLineNum++}',
              oldContent: line,
              newLine: '',
              newContent: '',
              type: DiffType.deletion,
            ),
          );
        } else if (diff.operation == DIFF_INSERT) {
          diffLines.add(
            DiffLine(
              oldLine: '',
              oldContent: '',
              newLine: '${newLineNum++}',
              newContent: line,
              type: DiffType.addition,
            ),
          );
        } else {
          diffLines.add(
            DiffLine(
              oldLine: '${oldLineNum++}',
              oldContent: line,
              newLine: '${newLineNum++}',
              newContent: line,
              type: DiffType.equal,
            ),
          );
        }
      }
    }
    return diffLines;
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
