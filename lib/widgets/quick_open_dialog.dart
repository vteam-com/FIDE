import 'package:fide/constants/constants.dart';
import 'package:fide/models/quick_open_matcher.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The "Go to File" palette: a query box over the project files that best
/// match it, as in VS Code's Quick Open. Up and Down move the selection,
/// Enter opens it and Escape closes the palette.
class QuickOpenDialog extends StatefulWidget {
  /// Creates the palette over [files] of the project at [rootPath].
  const QuickOpenDialog({
    super.key,
    required this.rootPath,
    required this.files,
  });

  /// Files to search, in the order listed while the query is empty.
  final List<String> files;

  /// Project root; results show their folder relative to it.
  final String rootPath;

  @override
  State<QuickOpenDialog> createState() => _QuickOpenDialogState();

  /// Shows the palette over [files]; resolves to the chosen file, null when
  /// dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String rootPath,
    required List<String> files,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_ /*context*/) =>
          QuickOpenDialog(rootPath: rootPath, files: files),
    );
  }
}

class _QuickOpenDialogState extends State<QuickOpenDialog> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _results = _rank('');
  int _selected = 0;

  /// Key of the selected row, to scroll it into view.
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.huge,
        AppSize.titleBarHeight,
        AppSpacing.huge,
        AppSpacing.huge,
      ),
      child: SizedBox(
        width: AppSize.quickOpenWidth,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _moveSelection(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _moveSelection(-1),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppPadding.panelContent,
                child: AppTextField(
                  controller: _controller,
                  hintText: 'Search files by name',
                  icon: Icons.search,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _open(),
                ),
              ),
              if (_results.isEmpty)
                const Padding(
                  padding: AppPadding.panelContent,
                  child: EmptyState(message: 'No matching files'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: AppSize.quickOpenMaxListHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _results.length; i++) _row(i),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Moves the selection by [delta] rows, wrapping around, and scrolls the
  /// new row into view.
  void _moveSelection(int delta) {
    if (_results.isEmpty) return;
    final previous = _selected;
    setState(() => _selected = (_selected + delta) % _results.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _selectedKey.currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        alignmentPolicy: _selected > previous
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  /// Re-ranks the files for [query] and selects the best one.
  void _onQueryChanged(String query) {
    setState(() {
      _results = _rank(query);
      _selected = 0;
    });
  }

  /// Closes the palette with the result at [index], the selected one when
  /// null.
  void _open([int? index]) {
    if (_results.isEmpty) return;
    Navigator.of(context).pop(_results[index ?? _selected]);
  }

  /// The files best matching [query].
  List<String> _rank(String query) => QuickOpenMatcher.rank(
    widget.files,
    query,
    rootPath: widget.rootPath,
    limit: AppMetric.quickOpenMaxResults,
  );

  /// The row for result [index]: its icon and relative path.
  Widget _row(int index) {
    final isSelected = index == _selected;
    return TreeRow.filePath(
      _results[index],
      key: isSelected ? _selectedKey : null,
      rootPath: widget.rootPath,
      highlighted: isSelected,
      onTap: () => _open(index),
    );
  }
}
