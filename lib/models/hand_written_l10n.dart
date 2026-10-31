import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Code written by hand into a generated localizations file, cut out so it
/// survives `flutter gen-l10n`: static members become top-level
/// declarations, extensions and other declarations move as they are.
class HandWrittenL10n {
  const HandWrittenL10n._({
    required this.source,
    required this.staticNames,
    required this.topLevelNames,
    required this.extensionMembers,
  });

  /// Cuts the members fCheck listed in [handWrittenMembers] (names, or
  /// `extension Name`) out of the generated [content] of [outputClass].
  factory HandWrittenL10n.extract(
    String content,
    String outputClass,
    List<String> handWrittenMembers,
  ) {
    final unit = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;
    final wanted = handWrittenMembers.toSet();
    final parts = <String>[];
    final staticNames = <String>[];
    final topLevelNames = <String>[];
    final extensionMembers = <String>[];

    for (final declaration in unit.declarations) {
      switch (declaration) {
        case ClassDeclaration(:final namePart, :final body)
            when namePart.typeName.lexeme == outputClass:
          for (final member in body.members) {
            final (names, keyword) = switch (member) {
              MethodDeclaration(:final name, :final modifierKeyword) => (
                [name.lexeme],
                modifierKeyword,
              ),
              FieldDeclaration(:final fields, :final staticKeyword) => (
                [for (final variable in fields.variables) variable.name.lexeme],
                staticKeyword,
              ),
              _ => (const <String>[], null),
            };
            if (keyword == null || !names.any(wanted.contains)) continue;
            staticNames.addAll(names);
            // The member without `static`, as a top-level declaration
            parts.add(
              content
                      .substring(member.offset, keyword.offset)
                      .replaceAll(RegExp(r'\n[ \t]+'), '\n') +
                  content.substring(keyword.end, member.end).trimLeft(),
            );
          }
        case ExtensionDeclaration(:final name, :final body)
            when wanted.contains('extension ${name?.lexeme ?? ''}'):
          parts.add(content.substring(declaration.offset, declaration.end));
          for (final member in body.members) {
            if (member is MethodDeclaration) {
              extensionMembers.add(member.name.lexeme);
            }
          }
        default:
          final name = _nameOf(declaration);
          if (name == null || !wanted.contains(name)) continue;
          parts.add(content.substring(declaration.offset, declaration.end));
          topLevelNames.add(name);
      }
    }
    return HandWrittenL10n._(
      source: parts.join('\n\n'),
      staticNames: staticNames,
      topLevelNames: topLevelNames,
      extensionMembers: extensionMembers,
    );
  }

  /// Members of the moved extensions, used as `context.member`.
  final List<String> extensionMembers;

  /// The moved code, as top-level declarations.
  final String source;

  /// Static members turned top-level, used as `Class.name` until now.
  final List<String> staticNames;

  /// Moved top-level declarations, used by their name.
  final List<String> topLevelNames;

  /// The declared name of a top-level [declaration], if it has one.
  static String? _nameOf(CompilationUnitMember declaration) =>
      switch (declaration) {
        ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
        FunctionDeclaration(:final name) => name.lexeme,
        MixinDeclaration(:final name) => name.lexeme,
        TopLevelVariableDeclaration(:final variables) =>
          variables.variables.first.name.lexeme,
        _ => null,
      };
}
