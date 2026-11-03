import 'package:fide/models/architecture_graph.dart';

part 'architecture_focus.architecture_role.dart';

/// What the architecture view highlights in [graph]: the [file] in focus
/// with the files it imports and the files importing it; with no file in
/// focus, the files matching the filter [query].
class ArchitectureFocus {
  /// The files highlighted.
  final ArchitectureGraph graph;

  /// The file hovered or selected; null for none.
  final String? file;

  /// Text the files' paths are filtered by, ignoring case; empty for none.
  final String query;

  /// Focuses [file] of [graph], filtered by [query].
  const ArchitectureFocus(this.graph, {this.file, this.query = ''});

  /// Whether the import of [target] by [source] touches the focused file.
  bool isHighlighted(String source, String target) =>
      file != null && (source == file || target == file);

  /// Whether [path] matches the non-empty filter [query].
  bool isMatch(String path) =>
      query.isNotEmpty &&
      graph.relativePath(path).toLowerCase().contains(query.toLowerCase());

  /// The files matching the filter, in the graph's order; none without
  /// one.
  List<String> get matches => graph.files.where(isMatch).toList();

  /// How to show [path].
  ArchitectureRole roleOf(String path) {
    final focused = file;
    if (focused == null) {
      return query.isEmpty || isMatch(path)
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
