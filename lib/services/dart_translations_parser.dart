import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fide/models/dart_translations.dart';

/// Reads a Dart localizations class, such as
/// `String get cancel => 'Cancel';`, back into the ARB messages of a
/// [DartTranslations].
class DartTranslationsParser {
  /// Creates a parser.
  const DartTranslationsParser();

  /// Placeholder types gen-l10n formats itself; others become `Object`.
  static const Set<String> _placeholderTypes = {
    'DateTime',
    'double',
    'int',
    'num',
    'String',
  };

  /// Reads the class in [content] that extends [outputClass].
  DartTranslations parse(String content, String outputClass) {
    final unit = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;
    final messages = <String, String>{};
    final placeholders = <String, Map<String, String>>{};
    final unsupported = <String>[];
    for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
      if (declaration.extendsClause?.superclass.toSource() != outputClass) {
        continue;
      }
      for (final member
          in declaration.body.members.whereType<MethodDeclaration>()) {
        if (member.isStatic || member.returnType?.toSource() != 'String') {
          continue;
        }
        final key = member.name.lexeme;
        final types = {
          for (final parameter
              in member.parameters?.parameters ?? <FormalParameter>[])
            if (parameter.name case final name?)
              name.lexeme: _placeholderType(parameter.type?.toSource()),
        };
        final message = switch (_returned(member.body)) {
          final StringLiteral literal => _message(literal, types.keys.toSet()),
          _ => null,
        };
        if (message == null) {
          unsupported.add(key);
          continue;
        }
        messages[key] = message;
        if (types.isNotEmpty) placeholders[key] = types;
      }
    }
    return DartTranslations(
      messages: messages,
      placeholders: placeholders,
      unsupported: unsupported,
    );
  }

  /// The expression [body] returns, if it only returns one.
  static Expression? _returned(FunctionBody body) => switch (body) {
    ExpressionFunctionBody(:final expression) => expression,
    BlockFunctionBody(:final block)
        when block.statements.length == 1 &&
            block.statements.single is ReturnStatement =>
      (block.statements.single as ReturnStatement).expression,
    _ => null,
  };

  /// [literal] as an ARB message with a `{name}` for each interpolated
  /// parameter in [parameters]; null for other interpolations or braces.
  static String? _message(StringLiteral literal, Set<String> parameters) {
    final text = StringBuffer();
    bool add(StringLiteral part) {
      switch (part) {
        case SimpleStringLiteral(:final value):
          if (value.contains('{') || value.contains('}')) return false;
          text.write(value);
        case StringInterpolation(:final elements):
          for (final element in elements) {
            switch (element) {
              case InterpolationString(:final value):
                if (value.contains('{') || value.contains('}')) return false;
                text.write(value);
              case InterpolationExpression(
                    expression: SimpleIdentifier(:final name),
                  )
                  when parameters.contains(name):
                text.write('{$name}');
              default:
                return false;
            }
          }
        case AdjacentStrings(:final strings):
          return strings.every(add);
      }
      return true;
    }

    return add(literal) ? text.toString() : null;
  }

  /// The ARB placeholder type for the Dart parameter type [type].
  static String _placeholderType(String? type) =>
      _placeholderTypes.contains(type) ? type! : 'Object';
}
