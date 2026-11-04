// ignore_for_file: deprecated_member_use

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_header_band.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

part 'side_by_side_diff.diff_line.dart';
part 'side_by_side_diff.minimap.dart';

/// Shows two versions of a text side by side, deleted lines in red and
/// added lines in green, with buttons to jump between changes and a
/// minimap of where the changes are.
class SideBySideDiff extends StatefulWidget {
  /// Creates a diff of [oldText] against [newText].
  const SideBySideDiff({
    super.key,
    required this.oldText,
    required this.newText,
  });

  /// Character code of the first encoded line; 0 is skipped because some
  /// tools treat the null character as a string terminator.
  static const int _firstLineCode = 1;

  /// The modified version, shown on the right.
  final String newText;

  /// The original version, shown on the left.
  final String oldText;

  /// Indexes in [lines] where each change starts: a deleted or added line
  /// that follows an unchanged line or the start of the text.
  static List<int> changeStarts(List<DiffLine> lines) => [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].type != DiffType.equal &&
          (i == 0 || lines[i - 1].type == DiffType.equal))
        i,
  ];

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

  @override
  State<SideBySideDiff> createState() => _SideBySideDiffState();
}

class _SideBySideDiffState extends State<SideBySideDiff> {
  late List<int> _changeStarts;

  /// Unchanged lines kept in view above a change jumped to.
  static const int _contextLines = 3;
  late List<DiffLine> _lines;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _computeLines();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SideBySideDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText) {
      _computeLines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedSurface(
      padding: SurfacePadding.none,
      child: Column(
        children: [
          SurfaceHeaderBand(
            child: Row(
              children: [
                _buildHeaderLabel('Original'),
                _buildColumnDivider(AppSize.diffHeaderDividerHeight),
                _buildHeaderLabel('Modified'),
                _buildChangeNavigation(),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemExtent: AppSize.diffRowHeight,
                    itemCount: _lines.length,
                    itemBuilder: (_ /* context */, index) =>
                        _buildRow(_lines[index]),
                  ),
                ),
                _DiffMinimap(lines: _lines, controller: _scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The line shown just under the context lines at the top of the view:
  /// where a jumped-to change sits.
  int get _anchorLine => _scrollController.hasClients
      ? (_scrollController.offset / AppSize.diffRowHeight).round() +
            _contextLines
      : _contextLines;

  /// The previous / next change buttons and the count of changes; the
  /// buttons enable as the view scrolls past changes.
  Widget _buildChangeNavigation() {
    return ListenableBuilder(
      listenable: _scrollController,
      builder: (_ /* context */, _ /* child */) {
        final previous = _previousChange;
        final next = _nextChange;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_changeStarts.length} '
              '${_changeStarts.length == 1 ? 'change' : 'changes'}',
              style: AppTextStyle.caption,
            ),
            const SizedBox(width: AppSpacing.small),
            CompactIconButton(
              icon: Icons.keyboard_arrow_up,
              tooltip: 'Previous change',
              onPressed: previous == null ? null : () => _jumpTo(previous),
            ),
            CompactIconButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Next change',
              onPressed: next == null ? null : () => _jumpTo(next),
            ),
          ],
        );
      },
    );
  }

  /// The thin line, [height] tall, between the original and modified sides.
  Widget _buildColumnDivider(double height) {
    return SizedBox(
      height: height,
      child: const VerticalDivider(width: AppSize.borderThin),
    );
  }

  /// The bold title above one side of the diff.
  Widget _buildHeaderLabel(String label) {
    return Expanded(child: Text(label, style: AppTextStyle.captionStrong));
  }

  /// One diff row: the original side, a divider and the modified side,
  /// tinted when the line was deleted or added.
  Widget _buildRow(DiffLine line) {
    return ColoredBox(
      color: line.type.rowTint ?? Colors.transparent,
      child: Row(
        children: [
          _buildSide(
            line.oldLine,
            line.oldContent,
            line.type == DiffType.deletion ? line.type.markColor : null,
          ),
          _buildColumnDivider(AppSize.diffRowHeight),
          _buildSide(
            line.newLine,
            line.newContent,
            line.type == DiffType.addition ? line.type.markColor : null,
          ),
        ],
      ),
    );
  }

  /// One side of a diff row: the dimmed [lineNumber], then [content] in
  /// [contentColor], or the theme's text color when null. Long lines are
  /// clipped so every row keeps the same height.
  Widget _buildSide(String lineNumber, String content, Color? contentColor) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final style = AppTextStyle.code;
    return Expanded(
      child: Container(
        padding: AppPadding.listItem,
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
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: style.copyWith(color: contentColor ?? onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diffs the texts and finds where each change starts.
  void _computeLines() {
    _lines = SideBySideDiff.computeLines(widget.oldText, widget.newText);
    _changeStarts = SideBySideDiff.changeStarts(_lines);
  }

  /// Scrolls so the change starting at line [index] shows below a few
  /// unchanged lines of context.
  void _jumpTo(int index) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.animateTo(
      ((index - _contextLines) * AppSize.diffRowHeight).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: AppDuration.editorScroll,
      curve: Curves.easeOut,
    );
  }

  /// The first change below the anchor line, or null at the last one.
  int? get _nextChange {
    final anchor = _anchorLine;
    for (final start in _changeStarts) {
      if (start > anchor) return start;
    }
    return null;
  }

  /// The last change above the anchor line, or null at the first one.
  int? get _previousChange {
    final anchor = _anchorLine;
    for (final start in _changeStarts.reversed) {
      if (start < anchor) return start;
    }
    return null;
  }
}

/// Whether a diff line is unchanged, added or deleted.
enum DiffType {
  /// The line is the same in both versions.
  equal,

  /// The line is only in the modified version.
  addition,

  /// The line is only in the original version.
  deletion;

  /// The line's text and minimap color: green when added, red when
  /// deleted, null when unchanged.
  Color? get markColor => switch (this) {
    DiffType.equal => null,
    DiffType.addition => Colors.green[AppShade.strong],
    DiffType.deletion => Colors.red[AppShade.strong],
  };

  /// The faint background behind the whole row, null when unchanged.
  Color? get rowTint => switch (this) {
    DiffType.equal => null,
    DiffType.addition => Colors.green.withValues(alpha: AppOpacity.subtle),
    DiffType.deletion => Colors.red.withValues(alpha: AppOpacity.subtle),
  };
}
