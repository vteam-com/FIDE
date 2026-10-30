import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:flutter/material.dart';

/// A search box with a toggle that reveals the replacement box under it;
/// shared by find-in-file and the project search panel. Replace starts
/// hidden, since searching is the common case.
///
/// Each box is followed by its buttons in one column, so both boxes have
/// the same width.
class SearchReplaceField extends StatefulWidget {
  /// Creates the search row [searchField] with its hidden replace row
  /// editing [replaceController].
  const SearchReplaceField({
    super.key,
    required this.searchField,
    required this.searchActions,
    required this.replaceController,
    required this.onReplaceAll,
    this.onReplace,
  });

  /// Replaces the current match, also on Enter; no Replace button when
  /// null.
  final VoidCallback? onReplace;

  /// Replaces every match; the button is disabled when null.
  final VoidCallback? onReplaceAll;

  /// Holds the replacement text.
  final TextEditingController replaceController;

  /// Buttons after the search box, such as the search options.
  final List<Widget> searchActions;

  /// The search box.
  final Widget searchField;

  @override
  State<SearchReplaceField> createState() => _SearchReplaceFieldState();
}

class _SearchReplaceFieldState extends State<SearchReplaceField> {
  /// Focus of the replacement box, moved into it when it is revealed.
  final FocusNode _replaceFocusNode = FocusNode();

  /// Whether the replace row shows.
  bool _showReplace = false;

  @override
  void dispose() {
    _replaceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onReplace = widget.onReplace;
    return Row(
      spacing: AppSpacing.tiny,
      children: [
        CompactIconButton(
          icon: _showReplace ? Icons.expand_more : Icons.chevron_right,
          tooltip: _showReplace ? 'Hide replace' : 'Show replace',
          onPressed: _toggleReplace,
        ),
        Expanded(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _row(widget.searchField, widget.searchActions),
              if (_showReplace)
                _row(
                  top: AppSpacing.medium,
                  AppTextField(
                    controller: widget.replaceController,
                    focusNode: _replaceFocusNode,
                    hintText: 'Replace with...',
                    icon: Icons.find_replace,
                    onSubmitted: onReplace == null ? null : (_) => onReplace(),
                  ),
                  [
                    if (onReplace != null)
                      CompactIconButton(
                        icon: Icons.check,
                        tooltip: 'Replace (Enter)',
                        onPressed: onReplace,
                      ),
                    CompactIconButton(
                      icon: Icons.done_all,
                      tooltip: 'Replace all',
                      onPressed: widget.onReplaceAll,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// A table row of [field] followed by its [actions], right-aligned,
  /// [top] below the row above.
  static TableRow _row(Widget field, List<Widget> actions, {double top = 0}) =>
      TableRow(
        children: [
          Padding(
            padding: EdgeInsets.only(top: top),
            child: field,
          ),
          Padding(
            padding: EdgeInsets.only(left: AppSpacing.medium, top: top),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppSpacing.medium,
              children: actions,
            ),
          ),
        ],
      );

  /// Shows or hides the replace row, focusing the replacement box when it
  /// appears.
  void _toggleReplace() {
    setState(() => _showReplace = !_showReplace);
    if (_showReplace) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replaceFocusNode.requestFocus();
      });
    }
  }
}
