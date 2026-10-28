import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/outdated_package.dart';

/// What the Info panel shows about a project; produced by `ProjectAnalyzer`
/// and cached per project by `ProjectMetricsNotifier`.
///
/// The JSON keys match the map this class replaced, so existing caches
/// still load.
class ProjectMetrics {
  /// Nothing analyzed yet.
  static const ProjectMetrics empty = ProjectMetrics();

  /// Pubspec `name`.
  final String? name;

  /// Pubspec `version`.
  final String? version;

  /// Pubspec `description`.
  final String? description;

  /// Direct dependencies mapped to their version or a kind label.
  final Map<String, String> dependencies;

  /// Dev dependencies mapped to their version or a kind label.
  final Map<String, String> devDependencies;

  /// File count per extension.
  final Map<String, int> fileStats;

  /// Directory count per tracked top-level folder.
  final Map<String, int> directoryStructure;

  /// Health checks; null until the project has been analyzed.
  final HealthIndicators? health;

  /// Packages `flutter pub outdated` reported, by name.
  final Map<String, OutdatedPackage> outdated;

  /// Creates metrics from an analysis.
  const ProjectMetrics({
    this.name,
    this.version,
    this.description,
    this.dependencies = const {},
    this.devDependencies = const {},
    this.fileStats = const {},
    this.directoryStructure = const {},
    this.health,
    this.outdated = const {},
  });

  /// Reads metrics saved by [toJson].
  factory ProjectMetrics.fromJson(Map<String, dynamic> json) {
    Map<String, T> mapOf<T>(String key) =>
        (json[key] as Map<String, dynamic>?)?.cast<String, T>() ?? {};
    final health = json['healthIndicators'] as Map<String, dynamic>?;
    final outdated = json['outdated'] as Map<String, dynamic>? ?? {};
    return ProjectMetrics(
      name: json['name'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      dependencies: mapOf<String>('dependencies'),
      devDependencies: mapOf<String>('devDependencies'),
      fileStats: mapOf<int>('fileStats'),
      directoryStructure: mapOf<int>('directoryStructure'),
      health: health == null ? null : HealthIndicators.fromJson(health),
      outdated: outdated.map(
        (package, row) => MapEntry(
          package,
          OutdatedPackage.fromJson(row as Map<String, dynamic>),
        ),
      ),
    );
  }

  /// Total number of files counted.
  int get totalFiles => fileStats.values.fold(0, (sum, count) => sum + count);

  /// Returns a copy with the outdated packages replaced.
  ProjectMetrics copyWith({Map<String, OutdatedPackage>? outdated}) {
    return ProjectMetrics(
      name: name,
      version: version,
      description: description,
      dependencies: dependencies,
      devDependencies: devDependencies,
      fileStats: fileStats,
      directoryStructure: directoryStructure,
      health: health,
      outdated: outdated ?? this.outdated,
    );
  }

  /// The metrics as JSON for the per-project cache.
  Map<String, dynamic> toJson() => {
    'name': ?name,
    'version': ?version,
    'description': ?description,
    'dependencies': dependencies,
    'devDependencies': devDependencies,
    'fileStats': fileStats,
    'totalFiles': totalFiles,
    'directoryStructure': directoryStructure,
    if (health != null) 'healthIndicators': health!.toJson(),
    'qualityScore': ?health?.qualityScore,
    'outdated': outdated.map((package, row) => MapEntry(package, row.toJson())),
  };
}
