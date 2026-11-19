part of 'dry_analyzer.dart';

/// A file widgets are built in: the names it sees and the libraries it
/// imports, telling what code moved out of it must import.
class _SourceFile {
  _SourceFile(ResolvedUnitResult result)
    : scope = result.libraryFragment.scope,
      libraryUri = result.libraryElement.uri.toString(),
      _imports = result.libraryFragment.libraryImports;

  /// The core library, which no file imports.
  static const String _coreLibrary = 'dart:core';

  /// The file's library, as a `package:` URI in a project with a package
  /// configuration.
  final String libraryUri;

  /// The names the file sees.
  final Scope scope;

  final List<LibraryImport> _imports;

  /// The project's package name; null without a package configuration.
  String? get package => libraryUri.startsWith(packageScheme)
      ? libraryUri.substring(packageScheme.length).split('/').first
      : null;

  /// The URI another project file imports to see [element]: an unprefixed
  /// import of this file providing it, else its own library when it is
  /// the project's; empty for the core library, which needs no import;
  /// null for a private element or one this file sees through a prefix.
  String? importOf(Element element) {
    final library = element.library;
    final name = element.name;
    if (library == null || name == null || name.startsWith('_')) return null;
    final uri = library.uri.toString();
    if (uri == _coreLibrary) return '';
    for (final import in _imports) {
      if (import.prefix == null &&
          defines(import.namespace.definedNames2, element)) {
        return import.importedLibrary?.uri.toString();
      }
    }
    final package = this.package;
    return package != null && uri.startsWith('$packageScheme$package/')
        ? uri
        : null;
  }
}
