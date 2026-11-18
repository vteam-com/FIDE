part of 'widget_wrapper.dart';

/// How a [WidgetWrapper] holds the widget it wraps; each value is named
/// after the argument it writes.
enum WrapperSlot {
  /// A builder callback returning it: `builder: (context) => widget`.
  builder,

  /// Its only child: `child: widget`.
  child,

  /// The first of its children: `children: [widget]`.
  children;

  /// The argument holding [widget], the source of a widget.
  String hold(String widget) => switch (this) {
    builder => '$name: (context) => $widget',
    child => '$name: $widget',
    children => '$name: [$widget]',
  };
}
