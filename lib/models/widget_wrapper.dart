part 'widget_wrapper.wrapper_slot.dart';

/// A widget the outline's widget menu wraps another widget in: its name,
/// the arguments it is written with, and the slot holding the wrapped
/// widget.
class WidgetWrapper {
  /// Creates the wrapper [name], written with [arguments] before the
  /// [slot] holding the wrapped widget.
  const WidgetWrapper(
    this.name, {
    this.arguments = '',
    this.slot = WrapperSlot.child,
  });

  /// The padding [padding] writes around a widget, in logical pixels; a
  /// common Material spacing step, to be adjusted by the developer.
  static const int defaultPadding = 8;

  /// Lays out the wrapped widget in a builder's `context`.
  static const WidgetWrapper builder = WidgetWrapper(
    'Builder',
    slot: WrapperSlot.builder,
  );

  /// Centers the wrapped widget.
  static const WidgetWrapper center = WidgetWrapper('Center');

  /// Stacks the wrapped widget in a column, among the widgets to add.
  static const WidgetWrapper column = WidgetWrapper(
    'Column',
    slot: WrapperSlot.children,
  );

  /// The wrappers the widget menu offers, in its order, before the one
  /// named by the developer.
  static const List<WidgetWrapper> common = [
    padding,
    center,
    expanded,
    sizedBox,
    column,
    row,
    stack,
    builder,
  ];

  /// Fills the room a `Row`, `Column` or `Flex` leaves.
  static const WidgetWrapper expanded = WidgetWrapper('Expanded');

  /// Pads the wrapped widget by [defaultPadding] on every side.
  static const WidgetWrapper padding = WidgetWrapper(
    'Padding',
    arguments: 'padding: const EdgeInsets.all($defaultPadding)',
  );

  /// Lays the wrapped widget out in a row, among the widgets to add.
  static const WidgetWrapper row = WidgetWrapper(
    'Row',
    slot: WrapperSlot.children,
  );

  /// Sizes the wrapped widget, once its width or height is written.
  static const WidgetWrapper sizedBox = WidgetWrapper('SizedBox');

  /// Stacks the wrapped widget among the widgets to layer over it.
  static const WidgetWrapper stack = WidgetWrapper(
    'Stack',
    slot: WrapperSlot.children,
  );

  /// A widget class or constructor name, optionally prefixed:
  /// `Card`, `ListView.builder`, `material.Card`.
  static final RegExp _namePattern = RegExp(
    r'^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$',
  );

  /// The arguments written before [slot], such as `padding: ...`; empty
  /// when there are none.
  final String arguments;

  /// The widget's name as written: `Padding`, `ListView.builder`.
  final String name;

  /// How the wrapper holds the wrapped widget.
  final WrapperSlot slot;

  /// The wrapper named [name] by the developer, holding the wrapped widget
  /// in its `child`; null when [name] can't name a widget.
  static WidgetWrapper? named(String name) {
    final trimmed = name.trim();
    return _namePattern.hasMatch(trimmed) ? WidgetWrapper(trimmed) : null;
  }

  /// [widget], the source of a widget, wrapped: `Center(child: widget,)`.
  ///
  /// The trailing comma lets `dart format` lay the wrapper out on several
  /// lines, as Flutter code is.
  String wrap(String widget) {
    final held = slot.hold(widget);
    return arguments.isEmpty ? '$name($held,)' : '$name($arguments, $held,)';
  }
}
