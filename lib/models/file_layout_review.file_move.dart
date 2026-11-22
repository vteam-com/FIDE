part of 'file_layout_review.dart';

/// A library to move into the folder of its [category]: the file at
/// [path], with its parts, to [target]; [blocker] says why it can't move
/// there when it can't.
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
    this.blocker,
  });

  /// Why the file can't move, such as a file already at [target]; null
  /// when it can.
  final String? blocker;

  /// What kind of file it is.
  final CodeCategory category;

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
