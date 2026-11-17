part of 'dry_analyzer.dart';

/// A number written in a widget's styling setting.
class _LiteralUse {
  _LiteralUse({
    required this.value,
    required this.source,
    required this.offset,
    required this.type,
    required this.scope,
    required this.location,
    required this.context,
    required this.setting,
  });

  /// The widget and setting the number is written in, such as
  /// `Icon size`, which the constants it may stand for are ranked by.
  final String context;

  /// Where it is written.
  final DryLocation location;

  /// Offset of the number in its file.
  final int offset;

  /// The names its file sees, telling whether a constant needs importing.
  final Scope scope;

  /// The name of the setting holding the number, the nearest one:
  /// `borderRadius` for the `8` of
  /// `borderRadius: BorderRadius.circular(8)`; empty for none.
  final String setting;

  /// The number as written.
  final String source;

  /// The number's type where it is written: `double` for the `12` of a
  /// `double` setting.
  final DartType? type;

  /// Its value.
  final num value;
}
