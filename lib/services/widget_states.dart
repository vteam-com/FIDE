import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Tells a widget's `State` class in resolved code, by the Flutter class
/// it extends, `State`, which Riverpod's `ConsumerState` extends too.
///
/// Flutter makes a stateful widget two classes: the widget, and the
/// `State` its `createState` makes. The `State` is part of its widget, not
/// a class of its own: it lives in the widget's file, private
/// (`_FooState`), unless other files reach it by name, through a
/// `GlobalKey<FooState>`, as Flutter's own `FormState` is.
abstract final class WidgetStates {
  /// The Flutter class a widget's state extends.
  static const String stateClass = 'State';

  /// Whether [element] is a widget's `State`.
  static bool isState(InterfaceElement? element) =>
      _stateTypeOf(element) != null;

  /// The private name [state], a widget's public `State`, takes:
  /// `_FooState` for `FooState`.
  static String privateNameOf(String state) => '_$state';

  /// The widget [element] is the `State` of; null when it isn't a `State`
  /// or doesn't name its widget.
  static InterfaceElement? widgetOf(InterfaceElement? element) =>
      switch (_stateTypeOf(element)?.typeArguments.firstOrNull) {
        InterfaceType(:final element) => element,
        _ => null,
      };

  /// [element]'s `State<Widget>` supertype; null when it has none.
  static InterfaceType? _stateTypeOf(InterfaceElement? element) => element
      ?.allSupertypes
      .where((type) => type.element.name == stateClass)
      .firstOrNull;
}
