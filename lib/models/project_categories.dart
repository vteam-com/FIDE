import 'package:fide/models/code_category.dart';
import 'package:fide/models/project_node.dart';

/// A project's entries grouped for the Organized view.
class ProjectCategories {
  /// Entries of each category, in tree order.
  final Map<CodeCategory, List<ProjectNode>> nodes;

  /// Classes or translations counted in each category.
  final Map<CodeCategory, int> elementCounts;

  /// Dart files counted in each category; one class per file means it
  /// matches the category's element count.
  final Map<CodeCategory, int> sourceFileCounts;

  /// Paths of views that call `showDialog`, which get a warning.
  final Set<String> viewsWithDialogs;

  /// Creates a grouping.
  const ProjectCategories({
    required this.nodes,
    required this.elementCounts,
    required this.sourceFileCounts,
    required this.viewsWithDialogs,
  });
}
