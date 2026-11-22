import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/code_category.dart';
import 'package:fide/models/import_graph.dart';
import 'package:path/path.dart' as p;

part 'file_layout_review.file_layout_plan.dart';
part 'file_layout_review.file_move.dart';

/// What the Analyzer tab's File Layout review shows for a project: the
/// files of its `lib` folder outside the folder their kind belongs in,
/// each with where it moves, read once off the UI thread, and the
/// dependencies between its files, so no move adds a Layers issue.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class FileLayoutReview {
  /// Creates the review of [fileCount] libraries of the package
  /// [packageName].
  const FileLayoutReview({
    required this.moves,
    required this.fileCount,
    this.packageName,
    this.graph = const ImportGraph({}),
    this.parts = const {},
    this.allPlans = const {},
  });

  /// The kinds of files the review places, in display order.
  static const List<CodeCategory> categories = [
    CodeCategory.views,
    CodeCategory.widgets,
    CodeCategory.models,
  ];

  /// The plan of Move All for each kind, worked out off the UI thread:
  /// see [planAll].
  final Map<CodeCategory, FileLayoutPlan> allPlans;

  /// How many libraries were read.
  final int fileCount;

  /// The dependencies between the files of `lib`, at their current paths.
  final ImportGraph graph;

  /// The files to move, by kind then path.
  final List<FileMove> moves;

  /// The project's package name, which its `package:` imports start with;
  /// null without one in its pubspec.
  final String? packageName;

  /// The parts of each library of `lib` that has any, by path.
  final Map<String, List<String>> parts;

  /// What a file of [category] is, and where it belongs.
  static String describe(CodeCategory category) => switch (category) {
    CodeCategory.views =>
      'Screens and pages, widgets building a Scaffold or opened as a '
          'route, belong in ${targetOf(category)}.',
    CodeCategory.widgets =>
      'Widgets reading no app state, even through what they import, '
          'belong in ${targetOf(category)}.',
    CodeCategory.models =>
      'Plain Dart types, without Flutter, I/O or async code, belong in '
          '${targetOf(category)}.',
    _ => '',
  };

  /// The project-relative folder files of [category] move to, such as
  /// `lib/views`.
  static String targetOf(CodeCategory category) => category.directories.first;

  /// Whether a file of [category] at the project-relative [path] is in a
  /// folder its kind belongs in: one of [category]'s folder names among
  /// those of its path, so a feature's own `widgets` folder counts too. A
  /// widget's may also be a dialogs folder.
  static bool isPlaced(CodeCategory category, String path) {
    final names = {
      for (final kind in [
        category,
        if (category == CodeCategory.widgets) CodeCategory.dialogs,
      ])
        for (final directory in kind.directories) p.posix.basename(directory),
    };
    return p.posix.split(p.posix.dirname(path)).skip(1).any(names.contains);
  }

  /// The moves to make for [chosen] at once with no Layers issue added:
  /// see [FileLayoutPlan].
  FileLayoutPlan plan(Iterable<FileMove> chosen) =>
      _LayoutPlanner(this).plan(chosen);

  /// The plan of Move All for the files of [category]: [allPlans]'s, else
  /// [planAll] of those that can move.
  FileLayoutPlan allPlanOf(CodeCategory category) =>
      allPlans[category] ??
      planAll([
        for (final move in of(category))
          if (move.canMove) move,
      ]);

  /// The plan moving as many of [moves] at once as add no Layers issue:
  /// all of them when they can go together, else each in turn that keeps
  /// the plan free of new issues, the others left for later.
  FileLayoutPlan planAll(List<FileMove> moves) {
    final planner = _LayoutPlanner(this);
    final whole = planner.plan(moves);
    if (whole.addedIssue == null) return whole;
    final kept = <FileMove>[];
    var best = const FileLayoutPlan(moves: []);
    for (final move in moves) {
      final trial = planner.plan([...kept, move]);
      if (trial.addedIssue == null) {
        kept.add(move);
        best = trial;
      }
    }
    return best;
  }

  /// The plan of each of [moves] made alone, in order: [plan] for each,
  /// judging the project's current layers once.
  List<FileLayoutPlan> planEach(Iterable<FileMove> moves) {
    final planner = _LayoutPlanner(this);
    return [
      for (final move in moves) planner.plan([move]),
    ];
  }

  /// The moves of the files of [category], in order.
  List<FileMove> of(CodeCategory category) => [
    for (final move in moves)
      if (move.category == category) move,
  ];
}
