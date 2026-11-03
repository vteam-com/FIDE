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
  Iterable<String> foldersToExpand(ProjectNode root) =>
      isActive ? _foldersWithMatches(root) : const [];

  /// Whether [node] or anything below it matches the query.
  bool hasMatchingDescendant(ProjectNode node) {
    return matches(node) || node.children.any(hasMatchingDescendant);
  }

  /// Whether [node]'s name matches the query; everything matches when
  /// there is none.
  bool matches(ProjectNode node) {
    return !isActive || node.name.toLowerCase().contains(_query);
  }

  /// The folders at and below [node] holding a match.
  Iterable<String> _foldersWithMatches(ProjectNode node) sync* {
    if (!node.isDirectory || !hasMatchingDescendant(node)) return;
    yield node.path;
    for (final child in node.children) {
      yield* _foldersWithMatches(child);
    }
  }

  /// Reads the query from the [controller] and reports the change.
  void _read() {
    _query = controller.text.toLowerCase();
    _onChanged();
  }
}
