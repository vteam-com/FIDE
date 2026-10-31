/// A value passed to a [LookupField]: where its expression is and its
/// source.
typedef LookupFieldArgument = ({
  String path,
  int offset,
  int length,
  String source,
});

/// A read of a [LookupField], such as `widget.title`, spanning [offset] to
/// [end], with the `BuildContext` in scope there.
typedef LookupFieldRead = ({
  String path,
  int offset,
  int end,
  String contextName,
});

/// A widget's `String` field that callers without a `BuildContext` fill
/// with text, which can become a lookup function the widget calls with its
/// context: the field's type, every value passed to it and every read of
/// it, across the project.
class LookupField {
  /// Creates the field [name] of [className], its type annotation spanning
  /// [typeOffset] and [typeLength] in [path].
  const LookupField({
    required this.className,
    required this.name,
    required this.path,
    required this.typeOffset,
    required this.typeLength,
    required this.arguments,
    required this.reads,
  });

  /// Values passed to the field through its `this.` parameters.
  final List<LookupFieldArgument> arguments;

  /// The class declaring the field.
  final String className;

  /// The field's name.
  final String name;

  /// Absolute path of the file declaring the field.
  final String path;

  /// Reads of the field, each with a `BuildContext` in scope.
  final List<LookupFieldRead> reads;

  /// Length of the field's `String` type annotation.
  final int typeLength;

  /// Offset of the field's `String` type annotation.
  final int typeOffset;

  /// The field as one key, such as `HomeEntityListTab.searchHint`.
  String get id => '$className.$name';
}
