import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/quick_open_matcher.dart';

part 'architecture_focus.architecture_role.dart';

/// What the architecture view highlights in [graph]: the [file] in focus
/// with the files it imports and the files importing it; with no file in
/// focus, the files matching the filter [query].
class ArchitectureFocus {
  /// The files highlighted.
  final ArchitectureGraph graph;

  /// The file hovered or selected; null for none.
  final String? file;

  /// Text the files' paths are filtered by, as Go to File matches them;
  /// blank for none.
  final String query;

  /// Focuses [file] of [graph], filtered by [query].
  const ArchitectureFocus(this.graph, {this.file, this.query = ''});

  /// Whether the import of [target] by [source] touches the focused file.
  bool isHighlighted(String source, String target) =>
      file != null && (source == file || target == file);

  /// Whether a filter is set.
  bool get _isFiltered => query.trim().isNotEmpty;

  /// Whether [path] matches the filter [query].
  bool isMatch(String path) =>
      _isFiltered &&
      QuickOpenMatcher.score(graph.relativePath(path), query) != null;

  /// The files matching the filter, best match first as Go to File ranks
  /// them; none without a filter.
  List<String> get matches => _isFiltered
      ? QuickOpenMatcher.rank(
          graph.files,
          query,
          rootPath: graph.rootPath,
          limit: graph.files.length,
        )
      : const [];

  /// How to show [path].
  ArchitectureRole roleOf(String path) {
    final focused = file;
    if (focused == null) {
      return !_isFiltered || isMatch(path)
          ? ArchitectureRole.plain
          : ArchitectureRole.dimmed;
    }
    if (path == focused) return ArchitectureRole.focused;
    if (graph.callees[focused]?.contains(path) ?? false) {
      return ArchitectureRole.callee;
    }
    if (graph.callers[focused]?.contains(path) ?? false) {
      return ArchitectureRole.caller;
    }
    return ArchitectureRole.dimmed;
  }
}
