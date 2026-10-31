/// An import directive with its URI in group 1.
final RegExp _importDirective = RegExp(
  r'''^import\s+['"]([^'"]+)['"][^;]*;[^\n]*\n?''',
  multiLine: true,
);

/// Dart [content] importing [importUri], placed before the first package
/// import that sorts after it, else after the last import; unchanged when
/// an import already satisfies [isImported].
String withImport(
  String content,
  String importUri, {
  required bool Function(String) isImported,
}) {
  final imports = _importDirective.allMatches(content).toList();
  if (imports.any((import) => isImported(import[1]!))) return content;
  final directive = "import '$importUri';\n";
  if (imports.isEmpty) return '$directive\n$content';
  final next = imports
      .where(
        (import) =>
            import[1]!.startsWith('package:') &&
            import[1]!.compareTo(importUri) > 0,
      )
      .firstOrNull;
  final at = next?.start ?? imports.last.end;
  return content.replaceRange(at, at, directive);
}
