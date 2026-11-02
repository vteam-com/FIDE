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
}
