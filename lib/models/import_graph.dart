import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_parse.dart';
import 'package:fide/models/project_paths.dart';
import 'package:path/path.dart' as p;

/// The dependencies between a project's Dart files, as fCheck's Layers
/// check counts them: each file's imports, exports and parts, their
/// conditional URIs included, that name a file of the project, by
/// project-relative path with `/` separators.
///
/// FIDE builds the graph a refactoring would make; fCheck judges it with
/// `validateLayers`, the full Layers check: file and folder cycles, and
/// files and folders depending on a layer above theirs. A refactoring
/// makes no change that adds an issue to the graph before it.
class ImportGraph {
  /// Creates the graph of [edges], each file's dependencies by its path.
  const ImportGraph(this.edges);

  /// The graph of the Dart files of [contents], their text by path, in
  /// the package [packageName].
  factory ImportGraph.parse(
    Map<String, String> contents, {
    String? packageName,
  }) => ImportGraph({
    for (final MapEntry(key: path, value: content) in contents.entries)
      path: dependenciesIn(
        path,
        parseDart(content).unit,
        packageName: packageName,
      ),
  });

  /// The folder of a file at the project's root, which belongs to none.
  static const String _root = '.';

  /// A path an issue's message names, the whole match: a quoted one, or
  /// the one a cycle involves.
  static final RegExp _namedPath = RegExp(
    r'(?<=")[^"]+(?=")|(?<=involving )\S+',
  );

  /// The files each file depends on, by path; the files of the graph are
  /// its keys.
  final Map<String, Set<String>> edges;

  /// The Layers issues fCheck reports for the graph.
  List<fcheck.LayersIssue> get layerIssues => fcheck.validateLayers({
    for (final MapEntry(key: path, value: targets) in edges.entries)
      path: [
        for (final target in targets)
          if (edges.containsKey(target)) target,
      ],
  });

  /// The files that depend on each file, by path.
  Map<String, Set<String>> importers() {
    final importers = <String, Set<String>>{};
    for (final MapEntry(key: path, value: targets) in edges.entries) {
      for (final target in targets) {
        importers.putIfAbsent(target, () => {}).add(path);
      }
    }
    return importers;
  }

  /// The graph after the files of [moves], new path by current one, moved:
  /// the same dependencies between the files at their new paths.
  ImportGraph moved(Map<String, String> moves) => ImportGraph({
    for (final MapEntry(key: path, value: targets) in edges.entries)
      moves[path] ?? path: {
        for (final target in targets) moves[target] ?? target,
      },
  });

  /// The graph after the files of [changed], their new text by path, and
  /// [removed], by path, read in the package [packageName].
  ImportGraph updated(
    Map<String, String> changed, {
    Set<String> removed = const {},
    String? packageName,
  }) => ImportGraph({
    for (final MapEntry(key: path, value: targets) in edges.entries)
      if (!removed.contains(path) && !changed.containsKey(path)) path: targets,
    ...ImportGraph.parse(changed, packageName: packageName).edges,
  });

  /// The Layers issues of [after] that [before] has not, [added], and
  /// those of [before] that [after] has not, [fixed]: [after] is the graph
  /// [before] became, through the files of [moves], new path by current
  /// one, and edits.
  static ({List<fcheck.LayersIssue> added, List<fcheck.LayersIssue> fixed})
  compareIssues(
    List<fcheck.LayersIssue> before,
    List<fcheck.LayersIssue> after, {
    Map<String, String> moves = const {},
  }) {
    final had = {for (final issue in before) _keyOf(issue)};
    final has = {for (final issue in after) _keyOf(issue, moves)};
    return (
      added: [
        for (final issue in after)
          if (!had.contains(_keyOf(issue, moves))) issue,
      ],
      fixed: [
        for (final issue in before)
          if (!has.contains(_keyOf(issue))) issue,
      ],
    );
  }

  /// The project files [unit], the file at [path], depends on: what its
  /// imports, exports and parts name, in the package [packageName].
  static Set<String> dependenciesIn(
    String path,
    CompilationUnit unit, {
    String? packageName,
  }) => {
    for (final directive in unit.directives)
      if (directive case NamespaceDirective() || PartDirective())
        for (final uri in [
          (directive as UriBasedDirective).uri.stringValue,
          if (directive case NamespaceDirective(:final configurations))
            for (final configuration in configurations)
              configuration.uri.stringValue,
        ])
          ?resolve(uri, from: path, packageName: packageName),
  };

  /// The folder of the file at [path]; null at the project's root.
  static String? folderOf(String path) {
    final folder = p.posix.dirname(path);
    return folder == _root ? null : folder;
  }

  /// The folders [issue] names: those of the files it names, and the
  /// folders it names.
  static Set<String> foldersOf(fcheck.LayersIssue issue) => {
    for (final path in [
      issue.filePath,
      for (final match in _namedPath.allMatches(issue.message)) match[0]!,
    ])
      ?(p.posix.extension(path).isEmpty ? path : folderOf(path)),
  };

  /// The project-relative path of the file [uri] names in the file at
  /// [from], in the package [packageName]; null for a library outside the
  /// project.
  static String? resolve(
    String? uri, {
    required String from,
    String? packageName,
  }) {
    if (uri == null) return null;
    if (packageName != null) {
      final ownPrefix = '$packageScheme$packageName/';
      if (uri.startsWith(ownPrefix)) {
        return p.posix.normalize(
          p.posix.join(ProjectPaths.libFolder, uri.substring(ownPrefix.length)),
        );
      }
    }
    if (Uri.tryParse(uri)?.hasScheme ?? true) return null;
    return p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
  }

  /// What tells [issue] apart, the files of [moves], new path by current
  /// one, named by their current path, so an issue a move leaves as it
  /// was keeps its key.
  static String _keyOf(
    fcheck.LayersIssue issue, [
    Map<String, String> moves = const {},
  ]) {
    var key = '${issue.type.name} ${issue.filePath}: ${issue.message}';
    for (final MapEntry(key: from, value: to) in moves.entries) {
      key = key.replaceAll(to, from);
    }
    return key;
  }
}
