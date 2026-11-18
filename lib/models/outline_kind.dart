/// What an outline entry is, which sets whether its consumers are counted
/// (and, through `OutlineKindStyle`, its icon and color).
enum OutlineKind {
  /// A Dart class.
  dartClass(isCountable: true),

  /// A top-level Dart function.
  function(isCountable: true),

  /// A Dart method.
  method(isCountable: true),

  /// A top-level Dart variable.
  variable(isCountable: true),

  /// A widget a function returning widgets creates, nested under the
  /// widget whose slot (`child`, `children`, `body`, ...) it fills.
  widget(isWidget: true),

  /// A widget built elsewhere and placed in the widget tree: a helper's
  /// result, such as `_buildHeader()`, or a variable, such as `child`.
  widgetReference(isWidget: true),

  /// A Markdown `#` heading.
  heading1,

  /// A Markdown `##` heading.
  heading2,

  /// A Markdown `###` heading.
  heading3,

  /// A Markdown `####` heading.
  heading4,

  /// A Markdown `#####` heading.
  heading5,

  /// A Markdown `######` or deeper heading.
  heading6,

  /// A top-level YAML key.
  yamlKey;

  /// Whether the entry is a Dart declaration whose consumers can be
  /// counted.
  final bool isCountable;

  /// Whether the entry is part of a widget tree rather than a declaration,
  /// heading or key.
  final bool isWidget;

  const OutlineKind({this.isCountable = false, this.isWidget = false});

  /// Markdown headings, by level from 1.
  static const List<OutlineKind> headings = [
    heading1,
    heading2,
    heading3,
    heading4,
    heading5,
    heading6,
  ];

  /// The heading kind for a Markdown heading of 1-based [level]; levels
  /// past the deepest heading share it.
  static OutlineKind heading(int level) =>
      headings[level.clamp(1, headings.length) - 1];
}
