part of 'file_layout_review.dart';

/// A library to move into the folder of its [category]: the file at
/// [path], with its parts, to [target], and the files it takes [along]
/// so the project gains no Layers issue; [blocker] says why it can't
/// move there, and [addedIssue] which Layers issue moving it would add,
/// when it can't.
class FileMove {
  /// Creates the move of the library at [path], declaring [name] on
  /// [line], to [target].
  const FileMove({
    required this.category,
    required this.path,
    required this.target,
    required this.name,
    required this.line,
    this.parts = const [],
    this.along = const [],
    this.fixedIssues = const [],
    this.blocker,
    this.addedIssue,
  });

  /// The files that move with it, so the project gains no Layers issue:
  /// files it uses or that use it, which the review moves too, and files
  /// only the moved files use.
  final List<FileMove> along;

  /// Why the file can't move, such as a file already at [target]; null
  /// when it can.
  final String? blocker;

  /// The Layers issues fCheck reports that the move fixes, by message.
  final List<String> fixedIssues;

  /// What kind of file it is.
  final CodeCategory category;

  /// The Layers issue fCheck would report after moving it, by message,
  /// with no file to move along that prevents it; null when it adds
  /// none. Moved with other files, it may add none.
  final String? addedIssue;

  /// 1-based line of [name]'s declaration.
  final int line;

  /// The main type the file declares.
  final String name;

  /// Project-relative paths of the library's parts, which move with it.
  final List<String> parts;

  /// Project-relative path of the library, with `/` separators.
  final String path;

  /// Project-relative path the library moves to, with `/` separators.
  final String target;

  /// Whether the file can move on its own, with the files [along] it.
  bool get canMove => blocker == null && addedIssue == null;

  /// The move and the moves [along] it, all made at once.
  List<FileMove> get planned => [this, ...along];

  /// The new path of the library and each of its parts, by its current
  /// one, each part keeping its place relative to the library.
  Map<String, String> get paths {
    final from = p.posix.dirname(path);
    final to = p.posix.dirname(target);
    return {
      path: target,
      for (final part in parts)
        part: p.posix.join(to, p.posix.relative(part, from: from)),
    };
  }
}
