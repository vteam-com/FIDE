import 'dart:convert';

part 'pub_outdated.pub_outdated_package.dart';

/// What `flutter pub outdated --json` reports: the versions pub knows for
/// each package of a project.
class PubOutdated {
  /// The packages pub reported, in its order.
  final List<PubOutdatedPackage> packages;

  /// Creates a report of [packages].
  const PubOutdated(this.packages);

  /// JSON key of the package list.
  static const String _packagesKey = 'packages';

  /// Parses the [json] text `flutter pub outdated --json` prints:
  /// `{"packages": [{"package", "kind", "current": {...},
  /// "resolvable": {...}}]}`.
  ///
  /// Throws a [FormatException] when it isn't JSON of that shape.
  factory PubOutdated.parse(String json) {
    final dynamic data = jsonDecode(json);
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object, got ${data.runtimeType}',
        json,
      );
    }
    final packages = data[_packagesKey];
    if (packages is! List) {
      throw FormatException(
        'Expected "$_packagesKey" to be an array, got ${packages?.runtimeType}',
        json,
      );
    }
    return PubOutdated([
      for (final package in packages)
        if (package is Map<String, dynamic>)
          ?PubOutdatedPackage.fromJson(package),
    ]);
  }

  /// The direct and dev dependencies whose constraint can be raised: those
  /// with a resolvable version other than the current one.
  List<PubOutdatedPackage> get upgradable => [
    for (final package in packages)
      if (package.isDeclared && package.canUpgrade) package,
  ];
}
