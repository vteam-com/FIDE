import 'package:analyzer/dart/ast/ast.dart';

/// A widget created in code, read from its syntax alone, without types:
/// `Text('a')`, `const Padding(...)`, `ListView.builder(...)`,
/// `material.Text(...)`.
///
/// Shared by the outline, which lists the widgets a build function
/// creates, and the widget edits made from it, so both read the same
/// widgets.
class WidgetCreation {
  const WidgetCreation._(this.name, this.nameOffset, this.arguments);

  /// The slots that hold a list of widgets: `children`, `slivers`.
  static const Set<String> multiChildSlots = {'children', 'slivers'};

  /// The slots that hold the one widget a widget lays out: `child`,
  /// `sliver`.
  static const Set<String> singleChildSlots = {'child', 'sliver'};

  /// The arguments the widget is created with.
  final ArgumentList arguments;

  /// The widget's name as written, its constructor's included:
  /// `ListView.builder`.
  final String name;

  /// Where [name] starts in the source, after any `const` or `new`.
  final int nameOffset;

  /// The widget it lays out: what fills one of its [singleChildSlots];
  /// null when it has none.
  Expression? get child => _slotValue(singleChildSlots);

  /// The list of widgets it lays out: the list literal filling one of its
  /// [multiChildSlots]; null when it has none.
  ListLiteral? get children => switch (_slotValue(multiChildSlots)) {
    final ListLiteral list => list,
    _ => null,
  };

  /// The class created, without its import prefix or constructor name:
  /// `ListView` for `ListView.builder`, `Text` for `material.Text`.
  String get typeName =>
      name.split('.').firstWhere(isTypeName, orElse: () => name);

  /// The widget [expression] creates, or null when it creates none: a
  /// constructor call, spelled from a capital letter when read without
  /// types.
  static WidgetCreation? of(Expression expression) {
    switch (expression) {
      case InstanceCreationExpression(
        :final constructorName,
        :final argumentList,
      ):
        // Without types, `const A.b()` reads as type `b` of import prefix
        // `A`, so the name joins all three as written
        final type = constructorName.type;
        final name = [
          ?type.importPrefix?.name.lexeme,
          type.name.lexeme,
          ?constructorName.name?.name,
        ].join('.');
        return WidgetCreation._(name, constructorName.offset, argumentList);
      case MethodInvocation(:final target, :final methodName)
          when isTypeName(methodName.name) ||
              (target is SimpleIdentifier && isTypeName(target.name)):
        // A constructor read without types: `Text(...)`,
        // `ListView.builder(...)`, `material.Text(...)`
        final name = target == null
            ? methodName.name
            : '${target.toSource()}.${methodName.name}';
        return WidgetCreation._(
          name,
          expression.offset,
          expression.argumentList,
        );
      default:
        return null;
    }
  }

  /// Whether [name] is spelled as a type is, from a capital letter.
  static bool isTypeName(String name) {
    final first = name.replaceFirst('_', '');
    return first.isNotEmpty && first[0] != first[0].toLowerCase();
  }

  /// What fills the first of [slots] the widget is given; null when it is
  /// given none.
  Expression? _slotValue(Set<String> slots) => arguments.arguments
      .whereType<NamedArgument>()
      .where((argument) => slots.contains(argument.name.lexeme))
      .firstOrNull
      ?.argumentExpression;
}
