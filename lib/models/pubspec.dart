import 'dart:io';

import 'package:yaml/yaml.dart';

/// The parts of a `pubspec.yaml` the IDE reads.
class Pubspec {
  /// Package name.
  final String? name;

  /// Package version.
  final String? version;

  /// Package description.
  final String? description;

  /// The `dependencies:` section; empty when absent.
  final Map<String, Object?> dependencies;

  /// The `dev_dependencies:` section; empty when absent.
  final Map<String, Object?> devDependencies;

  /// The top-level `flutter:` section; empty when absent or empty.
  final Map<String, Object?> flutterSection;

  /// Whether the file has a top-level `flutter:` key, even an empty one.
  final bool hasFlutterSection;

  const Pubspec._({
    required this.name,
    required this.version,
    required this.description,
    required this.dependencies,
    required this.devDependencies,
    required this.flutterSection,
    required this.hasFlutterSection,
  });

  /// Parses pubspec [content]; content that isn't a YAML map yields an
  /// empty pubspec.
  factory Pubspec.parse(String content) {
    Object? document;
    try {
      document = loadYaml(content);
    } on YamlException {
      document = null;
    }
    final map = document is YamlMap ? document : YamlMap();
    return Pubspec._(
      name: map['name']?.toString(),
      version: map['version']?.toString(),
      description: map['description']?.toString(),
      dependencies: _section(map['dependencies']),
      devDependencies: _section(map['dev_dependencies']),
      flutterSection: _section(map['flutter']),
      hasFlutterSection: map.containsKey('flutter'),
    );
  }

  /// Reads and parses the pubspec at [path]; null when the file is missing.
  static Future<Pubspec?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return Pubspec.parse(await file.readAsString());
  }

  /// Whether this is a Flutter package: it depends on the Flutter SDK or
  /// has a `flutter:` section.
  bool get isFlutter {
    final flutter = dependencies['flutter'];
    return hasFlutterSection || (flutter is Map && flutter['sdk'] == 'flutter');
  }

  /// Whether `flutter: generate: true` is set.
  bool get generatesLocalizations => flutterSection['generate'] == true;

  /// Whether [package] is a direct dependency.
  bool dependsOn(String package) => dependencies.containsKey(package);

  /// [value] as a string-keyed map, or empty when it isn't a map.
  static Map<String, Object?> _section(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
}
