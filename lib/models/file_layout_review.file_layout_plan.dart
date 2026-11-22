part of 'file_layout_review.dart';

/// The moves to make at once for a choice of [FileMove]s, so the project
/// gains no Layers issue, as fCheck's `validateLayers` judges the graph
/// they make: the moves chosen, then the files moved along to prevent
/// each issue they would add; [addedIssue] is one no file could prevent,
/// the moves then not to be made.
class FileLayoutPlan {
  /// Creates the plan of [moves].
  const FileLayoutPlan({
    required this.moves,
    this.addedIssue,
    this.fixedIssues = const [],
  });

  /// The Layers issue the moves would add, by message; null when they add
  /// none.
  final String? addedIssue;

  /// The Layers issues the moves fix, by message.
  final List<String> fixedIssues;

  /// The moves to make, those chosen first.
  final List<FileMove> moves;
}

/// Plans moves on a [FileLayoutReview]: while the moves chosen would add
/// a Layers issue, it adds to them the files in the folders the issues
/// name that the moved files use or that use them and that the review
/// moves too, and the files only the moved files use, moved next to
/// their user.
class _LayoutPlanner {
  _LayoutPlanner(this._review);

  final FileLayoutReview _review;

  /// The files that depend on each file, by path.
  late final Map<String, Set<String>> _importers = _review.graph.importers();

  /// The moves the review offers, by path: those with a place to go.
  late final Map<String, FileMove> _offered = {
    for (final move in _review.moves)
      if (move.blocker == null) move.path: move,
  };

  /// Every file of `lib`, libraries and parts, by path.
  late final Set<String> _files = {
    ..._review.graph.edges.keys,
    for (final parts in _review.parts.values) ...parts,
  };

  /// The Layers issues of the files where they are.
  late final List<fcheck.LayersIssue> _issues = _review.graph.layerIssues;

  /// The moves of [chosen] and the files moved along, so the project
  /// gains no Layers issue.
  FileLayoutPlan plan(Iterable<FileMove> chosen) {
    final moves = {for (final move in chosen) move.path: move};
    while (true) {
      final paths = {for (final move in moves.values) ...move.paths};
      final (:added, :fixed) = ImportGraph.compareIssues(
        _issues,
        _review.graph.moved(paths).layerIssues,
        moves: paths,
      );
      if (added.isEmpty) {
        return FileLayoutPlan(
          moves: moves.values.toList(),
          fixedIssues: [for (final issue in fixed) issue.message],
        );
      }
      // fCheck names a cycle by one of its folders: when no file in the
      // folders it names helps, any file next to the moved ones may
      final named = _breakersOf(
        moves,
        paths,
        involved: {for (final issue in added) ...ImportGraph.foldersOf(issue)},
      );
      final along = named.isNotEmpty ? named : _breakersOf(moves, paths);
      if (along.isEmpty) {
        return FileLayoutPlan(
          moves: moves.values.toList(),
          addedIssue: added.first.message,
        );
      }
      for (final move in along) {
        moves.putIfAbsent(move.path, () => move);
      }
    }
  }

  /// The moves that may prevent the issues [moves], making [paths], add:
  /// those of the files a moved file uses, or that use one, which the
  /// review moves too; else, for a file used only by moved files, its
  /// move next to its user. Only files in the folders of [involved] when
  /// given, the folders the issues name, moved there or left there.
  List<FileMove> _breakersOf(
    Map<String, FileMove> moves,
    Map<String, String> paths, {
    Set<String>? involved,
  }) {
    final along = <FileMove>[];
    bool isIn(String path) =>
        involved?.contains(ImportGraph.folderOf(path)) ?? true;
    bool isLeftIn(String path) => !paths.containsKey(path) && isIn(path);
    for (final move in moves.values) {
      if (!isIn(move.target) && !isIn(move.path)) continue;
      for (final used in _review.graph.edges[move.path] ?? const {}) {
        if (!isLeftIn(used)) continue;
        if (_offered[used] ?? _helperMove(used, move, moves, paths)
            case final companion?) {
          along.add(companion);
        }
      }
      for (final user in _importers[move.path] ?? const <String>{}) {
        if (isLeftIn(user)) {
          if (_offered[user] case final companion?) along.add(companion);
        }
      }
    }
    return along;
  }

  /// The move of [path] next to [user], when only the files of [moves]
  /// use it and nothing is at its new place; null otherwise.
  FileMove? _helperMove(
    String path,
    FileMove user,
    Map<String, FileMove> moves,
    Map<String, String> paths,
  ) {
    final users = _importers[path] ?? const <String>{};
    if (users.isEmpty || !users.every(moves.containsKey)) return null;
    final helper = FileMove(
      category: user.category,
      path: path,
      target: p.posix.join(
        p.posix.dirname(user.target),
        p.posix.basename(path),
      ),
      name: p.posix.basenameWithoutExtension(path),
      line: 1,
      parts: _review.parts[path] ?? const [],
    );
    final taken = {..._files, ...paths.values};
    return helper.paths.values.any(taken.contains) ? null : helper;
  }
}
