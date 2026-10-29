import 'package:fide/models/code_category.dart';
import 'package:fide/models/project_node.dart';

/// A project's entries grouped for the Organized view.
class ProjectCategories {
  /// Entries of each category, in tree order.
  final Map<CodeCategory, List<ProjectNode>> nodes;

  /// Classes or translations counted in each category.
  final Map<CodeCategory, int> elementCounts;

  /// Public classes counted in each category's Dart files, at least one per
  /// file; one public class per file means it matches [sourceFileCounts].
  final Map<CodeCategory, int> publicClassCounts;

  /// Dart files counted in each category.
  final Map<CodeCategory, int> sourceFileCounts;

  /// Paths of Dart files declaring more than one public class, mapped to
  /// their public class count.
  final Map<String, int> multiClassFiles;

  /// Paths of folders holding, at any depth, files of [multiClassFiles],
  /// mapped to how many such files they hold.
  final Map<String, int> multiClassFolders;

  /// Paths of views that call `showDialog`, which get a warning.
  final Set<String> viewsWithDialogs;

  /// Creates a grouping.
  const ProjectCategories({
    required this.nodes,
    required this.elementCounts,
    required this.publicClassCounts,
    required this.sourceFileCounts,
    required this.viewsWithDialogs,
    required this.multiClassFiles,
    required this.multiClassFolders,
  });
}
