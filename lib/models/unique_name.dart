import 'package:analyzer/dart/ast/token.dart';

/// First number appended to a name that is already taken.
const int _firstSuffix = 2;

/// A digit at the start of a name, which no Dart name may start with.
final RegExp _leadingDigit = RegExp('^[0-9]');

/// A Dart identifier: a letter, `_` or `$`, then letters, digits, `_` or
/// `$`; for building patterns.
const String identifierPattern = r'[A-Za-z_$][\w$]*';

/// The members every Dart object has, which a generated member can't be
/// named after.
const Set<String> objectMembers = {
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

/// [base], or [base] followed by the first number from 2 making a name
/// [isTaken] rejects, such as `photos2`.
String uniqueName(String base, bool Function(String) isTaken) {
  var name = base;
  for (var suffix = _firstSuffix; isTaken(name); suffix++) {
    name = '$base$suffix';
  }
  return name;
}

/// [name], followed by [suffix] when it is a Dart keyword or in [reserved],
/// so it can name a declaration.
String safeIdentifier(
  String name, {
  required String suffix,
  Set<String> reserved = const {},
}) => Keyword.keywords.containsKey(name) || reserved.contains(name)
    ? '$name$suffix'
    : name;

/// [name], after [prefix] when it starts with a digit, so it can name a
/// declaration or a package.
String withoutLeadingDigit(String name, {required String prefix}) =>
    name.startsWith(_leadingDigit) ? '$prefix$name' : name;
