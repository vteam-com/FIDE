part of 'pub_outdated.dart';

/// One package of a [PubOutdated] report.
class PubOutdatedPackage {
  /// The package name.
  final String name;

  /// How the project depends on it: [directKind], [devKind] or transitive.
  final String kind;

  /// The version currently resolved; null when none is.
  final String? current;

  /// The newest version resolvable with the other dependencies; null when
  /// pub found none.
  final String? resolvable;

  /// Creates a package row.
  const PubOutdatedPackage({
    required this.name,
    required this.kind,
    this.current,
    this.resolvable,
  });

  /// Kind of a dependency declared under `dependencies`.
  static const String directKind = 'direct';

  /// Kind of a dependency declared under `dev_dependencies`.
  static const String devKind = 'dev';

  /// JSON keys of a package row.
  static const String _nameKey = 'package';
  static const String _kindKey = 'kind';
  static const String _currentKey = 'current';
  static const String _resolvableKey = 'resolvable';
  static const String _versionKey = 'version';

  /// Reads a row of `flutter pub outdated --json`; null when it has no
  /// package name.
  static PubOutdatedPackage? fromJson(Map<String, dynamic> json) {
    final name = json[_nameKey];
    if (name is! String) return null;
    return PubOutdatedPackage(
      name: name,
      kind: json[_kindKey]?.toString() ?? '',
      current: _versionOf(json[_currentKey]),
      resolvable: _versionOf(json[_resolvableKey]),
    );
  }

  /// The version in a `{"version": ...}` [entry]; null when it is missing
  /// or empty.
  static String? _versionOf(dynamic entry) {
    if (entry is! Map<String, dynamic>) return null;
    final version = entry[_versionKey]?.toString();
    return version == null || version.isEmpty ? null : version;
  }

  /// Whether the project declares the package itself, as a direct or dev
  /// dependency.
  bool get isDeclared => kind == directKind || kind == devKind;

  /// The pubspec section the package is declared in, by its [kind].
  String get pubspecSection =>
      kind == devKind ? 'dev_dependencies' : 'dependencies';

  /// Whether a resolvable version other than the current one exists.
  bool get canUpgrade =>
      current != null && resolvable != null && current != resolvable;
}
