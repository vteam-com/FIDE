import 'package:yaml/yaml.dart';

/// The parts of a `pubspec.yaml` the IDE reads.
class Pubspec {
  /// The `flutter: config:` key turning Swift Package Manager on or off.
  static const String _swiftPackageManagerKey = 'enable-swift-package-manager';

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

  /// The `flutter_launcher_icons:` section; empty when absent.
  final Map<String, Object?> launcherIconsSection;

  /// The 1-based line declaring each direct and dev dependency.
  final Map<String, int> dependencyLines;

  /// The 1-based line of `flutter: config: enable-swift-package-manager`;
  /// null when the project doesn't set it.
  final int? swiftPackageManagerLine;

  const Pubspec._({
    required this.name,
    required this.version,
    required this.description,
    required this.dependencies,
    required this.devDependencies,
    required this.flutterSection,
    required this.hasFlutterSection,
    required this.launcherIconsSection,
    required this.dependencyLines,
    required this.swiftPackageManagerLine,
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
      launcherIconsSection: _section(map['flutter_launcher_icons']),
      dependencyLines: {
        ..._keyLines(map.nodes['dependencies']),
        ..._keyLines(map.nodes['dev_dependencies']),
      },
      swiftPackageManagerLine: _keyLines(
        map.nodes['flutter'] is YamlMap
            ? (map.nodes['flutter']! as YamlMap).nodes['config']
            : null,
      )[_swiftPackageManagerKey],
    );
  }

  /// Whether this is a Flutter package: it depends on the Flutter SDK or
  /// has a `flutter:` section.
  bool get isFlutter {
    final flutter = dependencies['flutter'];
    return hasFlutterSection || (flutter is Map && flutter['sdk'] == 'flutter');
  }

  /// Whether `flutter: generate: true` is set.
  bool get generatesLocalizations => flutterSection['generate'] == true;

  /// Project-relative image paths `flutter_launcher_icons:` generates
  /// icons from: its own `image_path`, then each platform's.
  List<String> get launcherIconsImagePaths => [
    for (final section in [
      launcherIconsSection,
      for (final value in launcherIconsSection.values) _section(value),
    ])
      if (section['image_path'] case final String path) path,
  ];

  /// Whether `flutter: config: enable-swift-package-manager: false` keeps
  /// the project on CocoaPods.
  bool get disablesSwiftPackageManager =>
      _section(flutterSection['config'])[_swiftPackageManagerKey] == false;

  /// Whether [package] is a direct dependency.
  bool dependsOn(String package) => dependencies.containsKey(package);

  /// The 1-based line of each key of [node], a YAML map; empty when it
  /// isn't one.
  static Map<String, int> _keyLines(YamlNode? node) {
    if (node is! YamlMap) return const {};
    return {
      for (final key in node.nodes.keys)
        if (key is YamlNode) '${key.value}': key.span.start.line + 1,
    };
  }

  /// [value] as a string-keyed map, or empty when it isn't a map.
  static Map<String, Object?> _section(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
}
