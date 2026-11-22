import 'dart:io';

import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_package_config.dart';
import 'package:fide/models/preview_scan.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:path/path.dart' as p;

/// A type a library sees: its [name], the file declaring it ([path]) and
/// its [scan], the [library] whose imports resolve the names its
/// declaration uses, and the library a file imports to see it ([import]).
typedef PreviewSymbol = ({
  String name,
  String path,
  PreviewScan scan,
  String library,
  String import,
});

/// A type declared in a library: the file declaring it, that file's scan,
/// and the library, which is that file unless it is one of its parts.
typedef _Declared = ({String path, PreviewScan scan, String library});

/// What a library exports: the types it and its parts declare and those
/// the libraries it exports do, by name, and the SDK libraries it exports.
typedef _Exports = ({Map<String, _Declared> names, Set<String> sdk});

/// The types a library's code sees: unprefixed ones by name, prefixed
/// ones by prefix and name, and the SDK libraries it imports unprefixed.
typedef _Scope = ({
  Map<String, PreviewSymbol> names,
  Map<String, Map<String, PreviewSymbol>> prefixed,
  Set<String> sdk,
});

/// Tells which declaration a type name names in a library's code, from
/// the syntax of the project's files and its packages' alone: it follows
/// the library's imports, the libraries they export and their parts, as
/// the compiler does, but skips the SDK's libraries.
///
/// It reads files synchronously and keeps what it parsed, so it runs in a
/// background isolate, for one task.
class PreviewTypeResolver {
  /// Creates the resolver of a project whose packages are [packages] and
  /// whose own Dart files are [projectFiles]; it reads a file from
  /// [contents] when listed there, else from disk.
  PreviewTypeResolver({
    required this.packages,
    this.projectFiles = const [],
    Map<String, String> contents = const {},
  }) : _contents = {...contents};

  /// The resolver of the project at [projectPath], from the package config
  /// `pub get` wrote, if any.
  factory PreviewTypeResolver.ofProject(
    String projectPath, {
    List<String> projectFiles = const [],
    Map<String, String> contents = const {},
  }) {
    final configPath = p.join(projectPath, DartPackageConfig.file);
    final config = _read(configPath);
    return PreviewTypeResolver(
      packages: config.isEmpty
          ? const DartPackageConfig()
          : DartPackageConfig.parse(config, configPath: configPath),
      projectFiles: projectFiles,
      contents: contents,
    );
  }

  /// The project's packages, mapping `package:` URIs to files.
  final DartPackageConfig packages;

  /// The project's own Dart files, sorted, searched for a class to build
  /// in place of an abstract one.
  final List<String> projectFiles;

  final Map<String, String> _contents;
  final Map<String, PreviewScan> _scans = {};
  final Map<String, _Exports> _exports = {};
  final Map<String, _Scope> _scopes = {};

  /// The content of the Dart file at [path]; empty when it can't be read.
  String contentOf(String path) => _contents[path] ??= _read(path);

  /// The scan of the Dart file at [path].
  PreviewScan scanOf(String path) =>
      _scans[path] ??= const PreviewScanner().scan(contentOf(path));

  /// The type [name] names in the code of the library at [library],
  /// written after the import prefix [prefix] when not null; null when the
  /// library sees no such type but maybe one of the SDK's.
  PreviewSymbol? resolve(String name, {required String library, String? prefix}) {
    final scope = _scopeOf(library);
    return prefix == null ? scope.names[name] : scope.prefixed[prefix]?[name];
  }

  /// Whether the library at [library] imports the SDK library [uri],
  /// directly or through a library that exports it.
  bool importsSdk(String library, String uri) =>
      _scopeOf(library).sdk.contains(uri);

  /// The first class of the project, by path, that code can build and
  /// that extends, implements or mixes in [name]; null without one.
  PreviewSymbol? implementationOf(String name) {
    final word = RegExp('\\b${RegExp.escape(name)}\\b');
    for (final path in projectFiles) {
      if (!word.hasMatch(contentOf(path))) continue;
      final scan = scanOf(path);
      if (scan.isPart) continue;
      for (final type in scan.classes) {
        if (type.isConstructible && type.supertypes.contains(name)) {
          return (
            name: type.name,
            path: path,
            scan: scan,
            library: path,
            import: path,
          );
        }
      }
    }
    return null;
  }

  /// The URI the file at [from] imports the library at [library] with:
  /// its `package:` URI, else a relative one.
  String importUri(String library, {required String from}) =>
      packages.uriOf(library) ?? relativeUriOf(library, from: from);

  /// The scope of the library at [library]: its own types, then those of
  /// its imports, the first import of a name winning.
  _Scope _scopeOf(String library) {
    final cached = _scopes[library];
    if (cached != null) return cached;
    final names = <String, PreviewSymbol>{};
    final prefixed = <String, Map<String, PreviewSymbol>>{};
    final sdk = <String>{};
    PreviewSymbol symbol(String name, _Declared declared, String import) => (
      name: name,
      path: declared.path,
      scan: declared.scan,
      library: declared.library,
      import: import,
    );
    for (final MapEntry(key: name, value: declared)
        in _declared(library).entries) {
      names[name] = symbol(name, declared, library);
    }
    for (final directive in scanOf(library).imports) {
      final prefix = directive.prefix;
      final uri = directive.uri;
      if (packages.isSdk(uri)) {
        if (prefix == null) sdk.add(uri);
        continue;
      }
      final path = _pathOf(uri, from: library);
      if (path == null) continue;
      final exports = _exportsOf(path);
      if (prefix == null) sdk.addAll(exports.sdk);
      final target = prefix == null
          ? names
          : prefixed.putIfAbsent(prefix, () => {});
      for (final MapEntry(key: name, value: declared)
          in exports.names.entries) {
        if (directive.shows(name)) {
          target.putIfAbsent(name, () => symbol(name, declared, path));
        }
      }
    }
    return _scopes[library] = (names: names, prefixed: prefixed, sdk: sdk);
  }

  /// What the library at [library] exports, each library computed once;
  /// a library exporting itself back sees nothing from the second time.
  _Exports _exportsOf(String library) {
    final cached = _exports[library];
    if (cached != null) return cached;
    _exports[library] = (names: const {}, sdk: const {});
    final names = {
      for (final MapEntry(key: name, value: declared)
          in _declared(library).entries)
        if (!_isPrivate(name)) name: declared,
    };
    final sdk = <String>{};
    for (final directive in scanOf(library).exports) {
      final uri = directive.uri;
      if (packages.isSdk(uri)) {
        sdk.add(uri);
        continue;
      }
      final path = _pathOf(uri, from: library);
      if (path == null) continue;
      final exported = _exportsOf(path);
      sdk.addAll(exported.sdk);
      for (final MapEntry(key: name, value: declared)
          in exported.names.entries) {
        if (directive.shows(name)) names.putIfAbsent(name, () => declared);
      }
    }
    return _exports[library] = (names: names, sdk: sdk);
  }

  /// The types the library at [library] and its parts declare, by name.
  Map<String, _Declared> _declared(String library) {
    final scan = scanOf(library);
    final files = [
      (library, scan),
      for (final part in scan.parts)
        if (_pathOf(part, from: library) case final path?)
          (path, scanOf(path)),
    ];
    return {
      for (final (path, file) in files)
        for (final name in file.typeNames)
          name: (path: path, scan: file, library: library),
    };
  }

  /// The file [uri] names in the file at [from]; null for an SDK library
  /// or a package the project doesn't resolve.
  String? _pathOf(String uri, {required String from}) {
    if (uri.startsWith(packageScheme)) return packages.pathOf(uri);
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.hasScheme) return null;
    return p.normalize(p.join(p.dirname(from), p.fromUri(parsed)));
  }

  /// The content of the file at [path]; empty when it can't be read.
  static String _read(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return '';
    }
  }

  static bool _isPrivate(String name) => name.startsWith('_');
}
