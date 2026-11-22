import 'package:flutter/foundation.dart';

/// A Dart type as written in code, such as `p.Box<int>?` or
/// `void Function(int value)`, split into the parts that picking a value
/// of the type needs; parsed from its text alone, resolving no name.
@immutable
class DartTypeText {
  /// Creates the type.
  const DartTypeText({
    required this.name,
    this.prefix,
    this.arguments = const [],
    this.isNullable = false,
    this.returnType,
    this.parameterCount = 0,
  });

  /// The keyword of a function type, and the [name] of one.
  static const String function = 'Function';

  /// Brackets of a parameter list's optional and named parameters, which
  /// don't change how many parameters it has.
  static final RegExp _optionalBrackets = RegExp(r'[{}\[\]]');

  /// A character that can be part of a name, or join a prefix to one.
  static final RegExp _namePart = RegExp(r'[\w$.]');

  /// Parses [text], such as `Map<String, int>?`.
  factory DartTypeText.parse(String text) {
    var type = text.trim();
    final isNullable = type.endsWith('?');
    if (isNullable) type = type.substring(0, type.length - 1).trimRight();
    final at = _functionAt(type);
    if (at != null) {
      final open = type.indexOf('(', at);
      return DartTypeText(
        name: function,
        isNullable: isNullable,
        returnType: type.substring(0, at).trim(),
        parameterCount: _split(
          type
              .substring(open + 1, type.lastIndexOf(')'))
              .replaceAll(_optionalBrackets, ''),
        ).length,
      );
    }
    final open = type.indexOf('<');
    if (type.startsWith('(') || (open >= 0) != type.endsWith('>')) {
      // A record, or a type this parser can't split: kept whole
      return DartTypeText(name: type, isNullable: isNullable);
    }
    final head = open < 0 ? type : type.substring(0, open).trim();
    final dot = head.indexOf('.');
    return DartTypeText(
      name: head.substring(dot + 1),
      prefix: dot < 0 ? null : head.substring(0, dot),
      arguments: open < 0
          ? const []
          : _split(type.substring(open + 1, type.length - 1)),
      isNullable: isNullable,
    );
  }

  /// The type's name, without its prefix nor its type arguments, such as
  /// `Box`; [function] for a function type.
  final String name;

  /// The import prefix, such as `p` in `p.Box`; null without one.
  final String? prefix;

  /// The type arguments as written, such as `[String, int]`.
  final List<String> arguments;

  /// Whether the type accepts null.
  final bool isNullable;

  /// For a function type, its return type as written, empty when it
  /// writes none; null for any other type.
  final String? returnType;

  /// For a function type, how many parameters it takes.
  final int parameterCount;

  /// Whether this is a function type, such as `void Function(int)`.
  bool get isFunction => returnType != null;

  /// The offset of the `Function` keyword of [type] when it is a function
  /// type, outside any type argument or parameter list; null otherwise.
  static int? _functionAt(String type) {
    var depth = 0;
    for (var i = 0; i < type.length; i++) {
      final char = type[i];
      if (char == '<' || char == '(') {
        depth++;
      } else if (char == '>' || char == ')') {
        depth--;
      } else if (depth == 0 &&
          type.startsWith(function, i) &&
          (i == 0 || !_namePart.hasMatch(type[i - 1]))) {
        final rest = type.substring(i + function.length).trimLeft();
        if (rest.startsWith('(') || rest.startsWith('<')) return i;
      }
    }
    return null;
  }

  /// [list] split at its commas outside angle brackets and parentheses,
  /// each part trimmed, the empty ones left out.
  static List<String> _split(String list) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < list.length; i++) {
      final char = list[i];
      if (char == '<' || char == '(') depth++;
      if (char == '>' || char == ')') depth--;
      if (char == ',' && depth == 0) {
        parts.add(list.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(list.substring(start));
    return [
      for (final part in parts)
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }
}
