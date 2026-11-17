import 'package:fide/models/project_node.dart';
import 'package:flutter/widgets.dart';

/// The Explorer's name filter: the query typed in its [controller] and
/// which nodes of the tree it keeps.
class TreeFilter {
  /// Holds the query; the filter field edits it.
  final TextEditingController controller = TextEditingController();

  final VoidCallback _onChanged;

  /// The query, lower-cased; empty when nothing is filtered.
  String _query = '';

  /// Creates a filter telling [onChanged] about every change of the query.
  TreeFilter({required this._onChanged}) {
    controller.addListener(_read);
  }

  /// Whether a query is set, so the tree is filtered.
  bool get isActive => _query.isNotEmpty;

  /// Drops the query.
  void clear() => controller.clear();

  /// Releases the [controller].
  void dispose() {
    controller.removeListener(_read);
    controller.dispose();
  }

  /// The folders under [root], itself included, to expand so every match
  /// shows: those with a matching descendant; none while not [isActive].
  Iterable<String> foldersToExpand(ProjectNode root) {
    if (!isActive) return const [];
    return _keptFolders(root, keptPaths(root));
  }

  /// The paths of the nodes at and below [root] the filtered tree keeps:
  /// those matching the query or holding a match below them.
  ///
  /// One post-order pass tests each node's name once, so a keystroke costs
  /// one walk of the tree, however deep it is.
  Set<String> keptPaths(ProjectNode root) {
    final kept = <String>{};
    bool visit(ProjectNode node) {
      var keep = matches(node);
      for (final child in node.children) {
        // Every child is visited, even once [node] is known to be kept
        if (visit(child)) keep = true;
      }
      if (keep) kept.add(node.path);
      return keep;
    }

    visit(root);
    return kept;
  }

  /// Whether [node]'s name matches the query; everything matches when
  /// there is none.
  bool matches(ProjectNode node) {
    return !isActive || node.name.toLowerCase().contains(_query);
  }

  /// The folders at and below [node] in [kept], parents first.
  static Iterable<String> _keptFolders(
    ProjectNode node,
    Set<String> kept,
  ) sync* {
    if (!node.isDirectory || !kept.contains(node.path)) return;
    yield node.path;
    for (final child in node.children) {
      yield* _keptFolders(child, kept);
    }
  }

  /// Reads the query from the [controller] and reports the change.
  void _read() {
    _query = controller.text.toLowerCase();
    _onChanged();
  }
}
