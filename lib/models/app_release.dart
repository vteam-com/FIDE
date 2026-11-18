import 'package:pub_semver/pub_semver.dart';

/// A FIDE release published on GitHub: its version, and where the build
/// of the operating system FIDE runs on downloads from.
class AppRelease {
  /// Creates release [version], its build downloading from [downloadUrl].
  const AppRelease({required this.version, required this.downloadUrl});

  /// What starts a release's tag, before its version: `v1.2.0`.
  static const String tagPrefix = 'v';

  /// Where the build of the operating system FIDE runs on downloads from.
  final Uri downloadUrl;

  /// The release's version, read from its tag.
  final Version version;

  /// The release GitHub's API describes in [json], with the build named
  /// [assetName]; null when it has no such build, or its tag names no
  /// version.
  static AppRelease? fromGitHub(Object? json, String assetName) {
    if (json case {
      'tag_name': final String tag,
      'assets': final List<Object?> assets,
    }) {
      final version = _versionOf(tag);
      for (final asset in assets) {
        if (asset
            case {
              'name': final String name,
              'browser_download_url': final String url,
            }
            when version != null && name == assetName) {
          return AppRelease(version: version, downloadUrl: Uri.parse(url));
        }
      }
    }
    return null;
  }

  /// The version release [tag] names, such as `v1.2.0`; null when it names
  /// none.
  static Version? _versionOf(String tag) {
    if (!tag.startsWith(tagPrefix)) return null;
    try {
      return Version.parse(tag.substring(tagPrefix.length));
    } on FormatException {
      return null;
    }
  }
}
