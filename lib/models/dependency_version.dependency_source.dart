part of 'dependency_version.dart';

/// Where a pubspec dependency comes from.
enum DependencySource {
  /// A version constraint resolved from pub.dev.
  hosted(null),

  /// The Flutter SDK (`sdk: flutter`).
  sdk('Flutter SDK'),

  /// Anything else: git, path, a custom host or no constraint.
  complex('Complex dependency');

  /// What the Info panel shows instead of a version; null for [hosted],
  /// which shows its constraint.
  final String? label;

  const DependencySource(this.label);
}
