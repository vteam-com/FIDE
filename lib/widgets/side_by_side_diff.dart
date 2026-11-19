// ignore_for_file: deprecated_member_use

import 'dart:isolate';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/pane_divider.dart';
import 'package:fide/widgets/previous_next_buttons.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/surface_header_band.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:material_ui/material_ui.dart';

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

  /// Highest character code a line is encoded as: one UTF-16 code unit.
  static const int _lastLineCode = 0xFFFF;

  /// How many distinct lines can be encoded, one character each.
  static const int _maxDistinctLines =
      _lastLineCode - _firstLineCode + 1 - _surrogateCount;

  /// How many UTF-16 surrogate codes there are, from [_surrogatesStart].
  static const int _surrogateCount = 0x800;

  /// First UTF-16 surrogate code, skipped when encoding lines since a lone
  /// surrogate isn't a character.
  static const int _surrogatesStart = 0xD800;

  /// Combined length, in characters, of texts diffed right away; longer
  /// ones are diffed in a background isolate, so the UI never waits.
  static const int maxInlineDiffLength = 20000;

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
  ///
  /// Runs on the calling isolate; [computeLinesInBackground] doesn't.
  static List<DiffLine> computeLines(String oldText, String newText) {
    final oldLines = oldText.isEmpty ? <String>[] : oldText.split('\n');
    final newLines = newText.split('\n');

    final diffLines = <DiffLine>[];
    int oldLineNum = 1;
    int newLineNum = 1;
    void add(int operation, String line) {
      if (operation == DIFF_DELETE) {
        diffLines.add(
          DiffLine(
            oldLine: '${oldLineNum++}',
            oldContent: line,
            newLine: '',
            newContent: '',
            type: DiffType.deletion,
          ),
        );
      } else if (operation == DIFF_INSERT) {
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

    if ({...oldLines, ...newLines}.length > _maxDistinctLines) {
      // Too many distinct lines to encode: shown as all replaced
      for (final line in oldLines) {
        add(DIFF_DELETE, line);
      }
      for (final line in newLines) {
        add(DIFF_INSERT, line);
      }
      return diffLines;
    }

    // Encode each distinct line as one character so diff_match_patch
    // compares whole lines instead of the characters inside them.
    final codes = <String, int>{};
    String encode(List<String> lines) => String.fromCharCodes(
      lines.map(
        (line) => codes.putIfAbsent(line, () => _lineCode(codes.length)),
      ),
    );
    final encodedOld = encode(oldLines);
    final encodedNew = encode(newLines);
    final linesByCode = {for (final e in codes.entries) e.value: e.key};
    for (final diff in DiffMatchPatch().diff(encodedOld, encodedNew)) {
      for (final code in diff.text.codeUnits) {
        add(diff.operation, linesByCode[code]!);
      }
    }
    return diffLines;
  }

  /// [computeLines] run in a background isolate, so diffing long texts
  /// doesn't hold up the UI.
  static Future<List<DiffLine>> computeLinesInBackground(
    String oldText,
    String newText,
  ) => Isolate.run(() => computeLines(oldText, newText));

  @override
  State<SideBySideDiff> createState() => _SideBySideDiffState();

  /// The character encoding the line first seen at [index]: one UTF-16
  /// code unit, skipping the surrogates.
  static int _lineCode(int index) {
    final code = index + _firstLineCode;
    return code < _surrogatesStart ? code : code + _surrogateCount;
  }
}

class _SideBySideDiffState extends State<SideBySideDiff> {
  /// Where each change starts in [_lines].
  List<int> _changeStarts = const [];

  /// Whether the texts are being diffed in the background.
  bool _computing = false;

  /// Unchanged lines kept in view above a change jumped to.
  static const int _contextLines = 3;

  /// Counts the diffs started, so a superseded one's result is dropped.
  int _generation = 0;

  /// The diff rows; null until the first diff is done.
  List<DiffLine>? _lines;

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
    final lines = _lines;
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
            child: lines == null
                ? const LoadingIndicator()
                : BusyBar.over(
                    busy: _computing,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemExtent: AppSize.diffRowHeight,
                            itemCount: lines.length,
                            itemBuilder: (_ /* context */, index) =>
                                _buildRow(lines[index]),
                          ),
                        ),
                        _DiffMinimap(
                          lines: lines,
                          controller: _scrollController,
                        ),
                      ],
                    ),
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

  /// The previous / next change buttons and which change is in view, or
  /// the count of changes above the first; they update as the view
  /// scrolls.
  Widget _buildChangeNavigation() {
    return ListenableBuilder(
      listenable: _scrollController,
      builder: (_ /* context */, _ /* child */) {
        final previous = _previousChange;
        final next = _nextChange;
        final count = _changeStarts.length;
        final reached = _changeStarts.where((s) => s <= _anchorLine).length;
        return PreviousNextButtons(
          label: reached == 0 ? count.count('change') : '$reached of $count',
          onPrevious: previous == null ? null : () => _jumpTo(previous),
          onNext: next == null ? null : () => _jumpTo(next),
          previousTooltip: 'Previous change',
          nextTooltip: 'Next change',
        );
      },
    );
  }

  /// The thin line, [height] tall, between the original and modified sides.
  Widget _buildColumnDivider(double height) {
    return SizedBox(height: height, child: const PaneDivider());
  }

  /// The bold title above one side of the diff.
  Widget _buildHeaderLabel(String label) {
    return Expanded(child: Text(label, style: AppTextStyle.captionStrong));
  }

  /// One diff row: the original side, a divider and the modified side,
  /// tinted when the line was deleted or added.
  Widget _buildRow(DiffLine line) {
    return ColoredBox(
      color:
          line.type.tone?.color.withValues(alpha: AppOpacity.subtle) ??
          Colors.transparent,
      child: Row(
        children: [
          _buildSide(
            line.oldLine,
            line.oldContent,
            line.type == DiffType.deletion ? line.type.tone : null,
          ),
          _buildColumnDivider(AppSize.diffRowHeight),
          _buildSide(
            line.newLine,
            line.newContent,
            line.type == DiffType.addition ? line.type.tone : null,
          ),
        ],
      ),
    );
  }

  /// One side of a diff row: the dimmed [lineNumber], then [content] in
  /// the color of [tone], or the theme's text color when null. Long lines
  /// are clipped so every row keeps the same height.
  Widget _buildSide(String lineNumber, String content, StatusTone? tone) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
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
                style: style.merge(AppTextStyle.lineNumber(context)),
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
                style: style.copyWith(
                  color: tone == null
                      ? onSurface
                      : tone.readableIn(colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diffs the texts and finds where each change starts: right away when
  /// they are short, else in the background, keeping the rows shown until
  /// then and dropping the result if newer texts came meanwhile.
  void _computeLines() {
    final generation = ++_generation;
    final oldText = widget.oldText;
    final newText = widget.newText;
    if (oldText.length + newText.length <= SideBySideDiff.maxInlineDiffLength) {
      _computing = false;
      _show(SideBySideDiff.computeLines(oldText, newText));
      return;
    }
    _computing = true;
    SideBySideDiff.computeLinesInBackground(oldText, newText).then((lines) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _computing = false;
        _show(lines);
      });
    });
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

  /// Shows [lines] as the diff.
  void _show(List<DiffLine> lines) {
    _lines = lines;
    _changeStarts = SideBySideDiff.changeStarts(lines);
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

  /// The tone coloring the line, as Git's `+`/`-` badges do: success when
  /// added, error when deleted, null when unchanged.
  StatusTone? get tone => switch (this) {
    DiffType.equal => null,
    DiffType.addition => StatusTone.success,
    DiffType.deletion => StatusTone.error,
  };
}
