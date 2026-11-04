part of 'cocoa_pods_migration.dart';

/// A package that still makes the app fall back to CocoaPods: its iOS
/// plugin has no Swift Package Manager manifest, as fCheck reports it.
class CocoaPodsBlocker {
  /// Creates the blocker [packageName] at [version], brought in by the
  /// direct dependency [introducedBy] (null when direct), declared at
  /// [line] of the pubspec.
  const CocoaPodsBlocker({
    required this.packageName,
    required this.version,
    required this.introducedBy,
    required this.line,
  });

  /// The direct dependency bringing the package in; null when the package
  /// is one itself.
  final String? introducedBy;

  /// 1-based pubspec line of the direct dependency to upgrade or replace.
  final int line;

  /// The package without a Swift Package Manager manifest.
  final String packageName;

  /// Its resolved version.
  final String version;

  /// The package, its version and where it comes from.
  String get description => introducedBy == null
      ? '$packageName $version'
      : '$packageName $version, through $introducedBy';
}
