import 'package:fide/models/outline_kind.dart';

/// One entry of the outline: a declaration, heading or key with where it
/// starts and how deeply it is nested.
class OutlineNode {
  /// Displayed name.
  final String name;

  /// What the entry is: a class, a heading, a key, ...
  final OutlineKind kind;

  /// 1-based line it starts on.
  final int line;

  /// 1-based column it starts at.
  final int column;

  /// Nesting depth, 0 for top level.
  final int level;

  /// Whether it is a method marked `@override`, which callers reach through
  /// the overridden member (or the framework) rather than by name.
  final bool isOverride;

  /// Creates an outline entry.
  const OutlineNode({
    required this.name,
    required this.kind,
    required this.line,
    this.column = 1,
    this.level = 0,
    this.isOverride = false,
  });

  /// The name callers use: `Foo<T>` is used as `Foo`.
  String get usedName => name.split('<').first;

  /// Whether [line] is on this entry or inside its scope within
  /// [outline], the ordered outline it belongs to: the scope runs to the
  /// line before the next entry nested as deeply or less, or past [line]
  /// when there is none.
  bool coversLine(int line, List<OutlineNode> outline) {
    if (line == this.line) return true;
    final index = outline.indexOf(this);
    if (index == _notInOutline) return false;

    var endLine = line;
    for (var i = index + 1; i < outline.length; i++) {
      final next = outline[i];
      if (next.level <= level) {
        endLine = next.line - 1;
        break;
      }
    }
    return line >= this.line && line <= endLine;
  }

  /// Whether [other] is this entry, even across re-parses.
  bool isSameAs(OutlineNode? other) =>
      other != null &&
      name == other.name &&
      kind == other.kind &&
      line == other.line &&
      column == other.column;

  /// [List.indexOf]'s answer for an entry not in the list.
  static const int _notInOutline = -1;
}
