import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/tree_order.dart';
import 'package:path/path.dart' as p;

/// The project's Dart files as fCheck layers them: which files each one
/// imports (its callees), which import it (its callers), and the layer it
/// sits in, from the entry points down to the files everything builds on.
///
/// Built from fCheck's analysis as is; nothing here re-analyzes the code.
class ArchitectureGraph {
  /// The layer every file sits in when fCheck could not layer them.
  static const int unlayered = 1;

  /// Files each file imports, in [files] order.
  final Map<String, List<String>> callees;

  /// Files importing each file, in [files] order.
  final Map<String, List<String>> callers;

  /// Absolute paths of the files, sorted by folder then name.
  final List<String> files;

  /// fCheck's layering findings for each file that has any.
  final Map<String, List<String>> issues;

  /// Whether fCheck layered the files; false when imports form a cycle,
  /// every file then sitting in the [unlayered] layer.
  final bool isLayered;

  /// The layer of each file, as fCheck numbers them: the lowest holds the
  /// entry points, each next one the files the previous ones import.
  final Map<String, int> layers;

  /// The project folder the files are shown relative to.
  final String rootPath;

  /// Creates the graph of [files] and their imports, [callees].
  ArchitectureGraph({
    required this.rootPath,
    required Iterable<String> files,
    required Map<String, Iterable<String>> callees,
    required Map<String, int> layers,
    this.issues = const {},
  }) : files = files.toSet().toList()..sort(_compareByFolder),
       callees = {},
       callers = {},
       isLayered = layers.isNotEmpty,
       layers = {} {
    for (final file in this.files) {
      callers[file] = [];
      this.layers[file] = layers[file] ?? unlayered;
    }
    // Callers fill in file order as the files are walked in that order
    for (final file in this.files) {
      final imported = {...?callees[file]}.where(callers.containsKey).toList()
        ..sort(_compareByFolder);
      this.callees[file] = imported;
      for (final callee in imported) {
        callers[callee]!.add(file);
      }
    }
  }

  /// The graph of fCheck's [metrics] for the project at [rootPath].
  factory ArchitectureGraph.fromMetrics(
    fcheck.ProjectMetrics metrics,
    String rootPath,
  ) {
    final graph = metrics.dependencyGraph;
    final issues = <String, List<String>>{};
    for (final issue in metrics.layersIssues) {
      final file = p.isAbsolute(issue.filePath)
          ? issue.filePath
          : p.join(rootPath, issue.filePath);
      issues.putIfAbsent(file, () => []).add(issue.message);
    }
    return ArchitectureGraph(
      rootPath: rootPath,
      files: {...graph.keys, for (final targets in graph.values) ...targets},
      callees: graph,
      layers: metrics.layersByFile,
      issues: issues,
    );
  }

  /// How many imports link the files.
  int get edgeCount =>
      callees.values.fold(0, (sum, targets) => sum + targets.length);

  /// The layer numbers in use, lowest first.
  List<int> get layerNumbers => layers.values.toSet().toList()..sort();

  /// The folder of [file], relative to [rootPath].
  String folderOf(String file) => p.dirname(relativePath(file));

  /// [file] relative to [rootPath].
  String relativePath(String file) => p.relative(file, from: rootPath);

  /// Orders paths by folder, then by file name within a folder, each as
  /// the project trees order them.
  static int _compareByFolder(String a, String b) {
    final byFolder = TreeOrder.compare(true, p.dirname(a), true, p.dirname(b));
    return byFolder != 0
        ? byFolder
        : TreeOrder.compare(false, p.basename(a), false, p.basename(b));
  }
}
