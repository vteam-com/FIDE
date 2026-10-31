import 'package:analyzer/dart/ast/token.dart';

/// First number appended to a name that is already taken.
const int _firstSuffix = 2;

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
