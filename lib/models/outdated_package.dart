import 'package:fide/constants/core_constants.dart';

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

  /// Header and separator rows of the table, which hold no package.
  static const Set<String> _tableHeadings = {'Package', '---'};

  /// Parses the table `flutter pub outdated` prints into one row per
  /// package name, skipping the headings.
  static Map<String, OutdatedPackage> parseTable(String output) {
    final outdated = <String, OutdatedPackage>{};
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < AppMetric.outdatedMinColumns ||
          _tableHeadings.contains(parts[0])) {
        continue;
      }
      outdated[parts[0]] = OutdatedPackage(
        current: parts[1],
        upgradable: parts[AppMetric.outdatedUpgradableColIndex],
        resolvable: parts[AppMetric.outdatedResolvableColIndex],
        latest: parts.length > AppMetric.outdatedLatestColIndex
            ? parts[AppMetric.outdatedLatestColIndex]
            : '',
      );
    }
    return outdated;
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
