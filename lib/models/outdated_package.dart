/// One row of `flutter pub outdated`: the versions pub knows for a package.
class OutdatedPackage {
  /// Version currently resolved.
  final String current;

  /// Newest version the current constraint allows.
  final String upgradable;

  /// Newest version resolvable with the other dependencies; `none` when no
  /// compatible version exists.
  final String resolvable;

  /// Newest published version.
  final String latest;

  /// Creates a row from pub's four version columns.
  const OutdatedPackage({
    required this.current,
    required this.upgradable,
    required this.resolvable,
    required this.latest,
  });

  /// Reads a row saved by [toJson].
  factory OutdatedPackage.fromJson(Map<String, dynamic> json) {
    return OutdatedPackage(
      current: json['current'] as String,
      upgradable: json['upgradable'] as String,
      resolvable: json['resolvable'] as String,
      latest: json['latest'] as String,
    );
  }

  /// Whether pub found no version compatible with the other dependencies.
  bool get hasNoResolvableVersion => resolvable == 'none';

  /// The row as JSON for the metrics cache.
  Map<String, dynamic> toJson() => {
    'current': current,
    'upgradable': upgradable,
    'resolvable': resolvable,
    'latest': latest,
  };
}
