/// What a project's build output looks like for one platform, ready to show.
class BuildArtifacts {
  /// Shown while the build directory is still being inspected.
  static const BuildArtifacts pending = BuildArtifacts(
    location: '…',
    size: '…',
    lastBuildTime: '…',
  );

  /// The project's own app icon, or null when it has none.
  final String? appIconPath;

  /// Directory holding this platform's output, or a reason there is none.
  final String location;

  /// Total size of the output, human readable.
  final String size;

  /// When anything under `build/` last changed.
  final String lastBuildTime;

  /// Creates a description of a platform's build output.
  const BuildArtifacts({
    this.appIconPath,
    required this.location,
    required this.size,
    required this.lastBuildTime,
  });
}
