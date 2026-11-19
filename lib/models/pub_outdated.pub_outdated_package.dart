part of 'pub_outdated.dart';

/// One package of a [PubOutdated] report.
class PubOutdatedPackage {
  /// The package name.
  final String name;

  /// How the project depends on it: [directKind], [devKind] or transitive.
  final String kind;

  /// The version currently resolved; null when none is.
  final String? current;

  /// The newest version the current constraint allows; null when none
  /// does.
  final String? upgradable;

  /// The newest version resolvable with the other dependencies; null when
  /// pub found none.
  final String? resolvable;

  /// The newest published version; null when pub doesn't know it.
  final String? latest;

  /// Creates a package row.
  const PubOutdatedPackage({
    required this.name,
    required this.kind,
    this.current,
    this.upgradable,
    this.resolvable,
    this.latest,
  });

  /// Kind of a dependency declared under `dependencies`.
  static const String directKind = 'direct';

  /// Kind of a dependency declared under `dev_dependencies`.
  static const String devKind = 'dev';

  /// JSON keys of a package row.
  static const String _nameKey = 'package';
  static const String _kindKey = 'kind';
  static const String _currentKey = 'current';
  static const String _upgradableKey = 'upgradable';
  static const String _resolvableKey = 'resolvable';
  static const String _latestKey = 'latest';
  static const String _versionKey = 'version';

  /// Reads a row of `flutter pub outdated --json`, or one [toJson] saved;
  /// null when it has no package name.
  static PubOutdatedPackage? fromJson(Map<String, dynamic> json) {
    final name = json[_nameKey];
    if (name is! String) return null;
    return PubOutdatedPackage(
      name: name,
      kind: json[_kindKey]?.toString() ?? '',
      current: _versionOf(json[_currentKey]),
      upgradable: _versionOf(json[_upgradableKey]),
      resolvable: _versionOf(json[_resolvableKey]),
      latest: _versionOf(json[_latestKey]),
    );
  }

  /// The row as pub writes it, for the metrics cache.
  Map<String, dynamic> toJson() => {
    _nameKey: name,
    _kindKey: kind,
    _currentKey: _versionToJson(current),
    _upgradableKey: _versionToJson(upgradable),
    _resolvableKey: _versionToJson(resolvable),
    _latestKey: _versionToJson(latest),
  };

  /// [version] as pub writes it: `{"version": ...}`, or null.
  static Map<String, String>? _versionToJson(String? version) =>
      version == null ? null : {_versionKey: version};

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

  /// Whether pub found no version compatible with the other dependencies.
  bool get hasNoResolvableVersion => resolvable == null;

  /// The row as a line of text: `http 1.0.0 → 1.1.0 (latest 2.0.0)`.
  String get summary =>
      '$name ${current ?? '-'} → ${resolvable ?? 'none'}'
      '${latest == null || latest == resolvable ? '' : ' (latest $latest)'}';
}
