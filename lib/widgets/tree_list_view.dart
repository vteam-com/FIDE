import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// One shown line of a [TreeListView]: its tree [node] and how deep in the
/// tree it sits.
typedef TreeListRow<T> = ({T node, int depth});

/// A scrolling tree, such as a folder tree or search results, drawn like
/// nested `TreeBranch`es but built lazily: only the rows on screen are
/// built, so a tree of thousands of rows costs no more than one screenful.
///
/// The tree comes flattened into [rows], its shown nodes in order (see
/// [flatten]); [rowBuilder] builds a node's own row, and each level
/// indents it by one step, as `TreeBranch` indents its children.
class TreeListView<T> extends StatelessWidget {
  /// Creates the scrolling list of [rows].
  const TreeListView({
    super.key,
    required this.rows,
    required this.rowBuilder,
    this.controller,
  });

  /// Scrolls the list, such as to reveal a row; the list's own when null.
  final ScrollController? controller;

  /// Builds the row of a node, without its children: they have rows of
  /// their own.
  final Widget Function(BuildContext context, T node) rowBuilder;

  /// The shown rows, top to bottom.
  final List<TreeListRow<T>> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Padding(
          padding: EdgeInsets.only(left: AppSpacing.xLarge * row.depth),
          child: rowBuilder(context, row.node),
        );
      },
    );
  }

  /// The shown rows of the trees under [roots], top to bottom: each node
  /// followed by the rows of its [childrenOf] (none for a leaf or a
  /// collapsed branch), one level deeper.
  static List<TreeListRow<T>> flatten<T>(
    Iterable<T> roots, {
    required Iterable<T> Function(T node) childrenOf,
  }) {
    final rows = <TreeListRow<T>>[];
    void visit(T node, int depth) {
      rows.add((node: node, depth: depth));
      for (final child in childrenOf(node)) {
        visit(child, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    return rows;
  }
}
