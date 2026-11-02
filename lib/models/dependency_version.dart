part 'dependency_version.dependency_source.dart';

/// A pubspec dependency's version: a hosted constraint, the Flutter SDK or
/// a source without a version (git, path...).
class DependencyVersion {
  /// The Flutter SDK.
  static const DependencyVersion sdk = DependencyVersion._(
    DependencySource.sdk,
  );

  /// A dependency without a pub.dev version.
  static const DependencyVersion complex = DependencyVersion._(
    DependencySource.complex,
  );

  /// Where the dependency comes from.
  final DependencySource source;

  /// The version constraint of a [DependencySource.hosted] dependency.
  final String? constraint;

  /// A pub.dev dependency constrained by [constraint].
  const DependencyVersion.hosted(String this.constraint)
    : source = DependencySource.hosted;

  const DependencyVersion._(this.source) : constraint = null;

  /// Reads a version saved by [toJson].
  factory DependencyVersion.fromJson(String json) {
    for (final source in DependencySource.values) {
      if (source.label == json) return DependencyVersion._(source);
    }
    return DependencyVersion.hosted(json);
  }

  /// Reads a pubspec dependency [value]: a constraint string, an
  /// `sdk: flutter` map, or anything else.
  factory DependencyVersion.fromPubspec(Object? value) => switch (value) {
    String constraint => DependencyVersion.hosted(constraint),
    Map() when value['sdk'] == 'flutter' => sdk,
    _ => complex,
  };

  /// Whether the package has a page on pub.dev.
  bool get isHosted => source == DependencySource.hosted;

  /// The constraint, or the source's label.
  String get label => constraint ?? source.label ?? '';

  /// The version as JSON for the metrics cache: its [label], as cached
  /// before this class existed.
  String toJson() => label;

  @override
  bool operator ==(Object other) =>
      other is DependencyVersion &&
      other.source == source &&
      other.constraint == constraint;

  @override
  int get hashCode => Object.hash(source, constraint);

  @override
  String toString() => label;
}
