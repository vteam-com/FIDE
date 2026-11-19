part of 'color_contrast_analyzer.dart';

/// A call in unresolved code, whichever node it parsed as: `Text(…)` and
/// `Color.fromARGB(…)` are method invocations until resolved, `const
/// Text(…)` an instance creation, `style.copyWith(…)` a method on a value.
class _Call {
  _Call._(this.node, this.typeName, this.member, this.arguments, {this.target});

  /// The node of the call.
  final AstNode node;

  /// The class constructed, such as `Container` or `ElevatedButton` for
  /// `ElevatedButton.styleFrom`; the function's name for a call of a
  /// function; empty for a method called on a value.
  final String typeName;

  /// The named constructor or method called, such as `styleFrom` or
  /// `copyWith`; null for an unnamed constructor or a function.
  final String? member;

  /// The arguments.
  final ArgumentList arguments;

  /// The value a method is called on, such as the style of
  /// `style.copyWith(…)`; null otherwise.
  final Expression? target;

  /// The class and named constructor, such as `FilledButton.tonal`.
  String get fullName => member == null ? typeName : '$typeName.$member';

  /// Whether the call constructs a class or calls one's static member, as
  /// its name is capitalized, private ones too.
  bool get isClass {
    final name = typeName.startsWith('_') ? typeName.substring(1) : typeName;
    return name.isNotEmpty && name[0] != name[0].toLowerCase();
  }

  /// The positional arguments, in order.
  List<Expression> get positional => [
    for (final argument in arguments.arguments)
      if (argument is! NamedArgument) argument.argumentExpression,
  ];

  /// The value of the named argument [name]; null when not given.
  Expression? operator [](String name) {
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == name) {
        return argument.argumentExpression;
      }
    }
    return null;
  }

  /// The named arguments: each name with its value.
  Iterable<(String, Expression)> get named => [
    for (final argument in arguments.arguments)
      if (argument is NamedArgument)
        (argument.name.lexeme, argument.argumentExpression),
  ];

  /// The call [node] is; null when it is not a call.
  static _Call? of(AstNode? node) => switch (node) {
    InstanceCreationExpression(:final constructorName, :final argumentList) =>
      _Call._(
        node,
        constructorName.type.name.lexeme,
        constructorName.name?.name,
        argumentList,
      ),
    MethodInvocation(:final target, :final methodName, :final argumentList) =>
      switch (target) {
        null => _Call._(node, methodName.name, null, argumentList),
        SimpleIdentifier(:final name) when _isClassName(name) => _Call._(
          node,
          name,
          methodName.name,
          argumentList,
        ),
        _ => _Call._(node, '', methodName.name, argumentList, target: target),
      },
    _ => null,
  };

  /// Whether [name] is capitalized, as class names are.
  static bool _isClassName(String name) =>
      name.isNotEmpty && name[0] != name[0].toLowerCase();
}
