import 'dart:convert';

import 'package:fide/models/dart_imports.dart';
import 'package:path/path.dart' as p;

/// The packages a Dart project resolves, as `pub get` writes them in its
/// `.dart_tool/package_config.json`: the `lib` folder of each, so a
/// `package:` URI maps to its file, and the Flutter SDK's folder.
class DartPackageConfig {
  /// Creates the config.
  const DartPackageConfig({this.libFolders = const {}, this.flutterRoot});

  /// The config file's path, relative to the project.
  static const String file = '.dart_tool/package_config.json';

  /// The scheme of the Dart SDK's libraries.
  static const String _dartScheme = 'dart:';

  /// Where a package's libraries are, in its root, when the config doesn't
  /// say.
  static const String _defaultPackageUri = 'lib/';

  /// Each package's `lib` folder, absolute, by package name.
  final Map<String, String> libFolders;

  /// The Flutter SDK's folder; null when the config doesn't name it.
  final String? flutterRoot;

  /// Parses [json], the config at the absolute path [configPath], whose
  /// relative root URIs it resolves against; empty when [json] isn't a
  /// package config.
  factory DartPackageConfig.parse(String json, {required String configPath}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const DartPackageConfig();
    }
    if (decoded is! Map<String, Object?>) return const DartPackageConfig();
    final base = Uri.file(configPath);
    Uri folder(Uri from, String uri) =>
        from.resolve(uri.endsWith('/') ? uri : '$uri/');
    String path(Uri uri) => p.normalize(uri.toFilePath());
    final packages = decoded['packages'];
    final root = decoded['flutterRoot'];
    return DartPackageConfig(
      libFolders: {
        if (packages is List)
          for (final package in packages.whereType<Map<String, Object?>>())
            if ((package['name'], package['rootUri']) case (
              final String name,
              final String rootUri,
            ))
              name: path(
                folder(
                  folder(base, rootUri),
                  package['packageUri'] as String? ?? _defaultPackageUri,
                ),
              ),
      },
      flutterRoot: root is String ? path(folder(base, root)) : null,
    );
  }

  /// The file the `package:` [uri] names; null for a library of the SDK,
  /// of a package the config doesn't list, or any other URI.
  String? pathOf(String uri) {
    if (!uri.startsWith(packageScheme)) return null;
    final path = uri.substring(packageScheme.length);
    final slash = path.indexOf('/');
    if (slash < 0) return null;
    final folder = libFolders[path.substring(0, slash)];
    if (folder == null || _isInSdk(folder)) return null;
    return p.joinAll([folder, ...path.substring(slash + 1).split('/')]);
  }

  /// Whether [uri] names a library of the SDK: a `dart:` one or one of a
  /// package of the Flutter SDK, such as `package:flutter/material.dart`.
  bool isSdk(String uri) {
    if (uri.startsWith(_dartScheme)) return true;
    if (!uri.startsWith(packageScheme)) return false;
    final name = uri.substring(packageScheme.length).split('/').first;
    final folder = libFolders[name];
    return folder != null && _isInSdk(folder);
  }

  /// The `package:` URI of the file at [path]; null outside every
  /// package's `lib` folder.
  String? uriOf(String path) {
    for (final MapEntry(key: name, value: folder) in libFolders.entries) {
      if (p.isWithin(folder, path)) {
        return packageUriOf(name, p.relative(path, from: folder));
      }
    }
    return null;
  }

  /// Whether [folder] is in the Flutter SDK.
  bool _isInSdk(String folder) {
    final root = flutterRoot;
    return root != null && p.isWithin(root, folder);
  }
}
