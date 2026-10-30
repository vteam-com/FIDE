// ignore: fcheck_secrets
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:path/path.dart' as p;

/// Reads a project's build output and app icon for the Execute panel and
/// the project overview.
class BuildArtifactsInspector {
  /// Size units, smallest first.
  static const List<String> _sizeUnits = ['B', 'KB', 'MB', 'GB'];

  /// App icon locations per platform, best resolution first, relative to the
  /// project root.
  static const Map<FlutterPlatform, List<String>> _iconCandidates = {
    FlutterPlatform.android: [
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/drawable/ic_launcher.png',
    ],
    FlutterPlatform.ios: [
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
    ],
    FlutterPlatform.macos: [
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png',
    ],
    FlutterPlatform.windows: ['windows/runner/resources/app_icon.ico'],
    FlutterPlatform.web: [
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
    ],
  };

  /// Platforms whose icon best represents the whole app, sharpest first.
  static const List<FlutterPlatform> _projectIconPlatforms = [
    FlutterPlatform.ios,
    FlutterPlatform.macos,
    FlutterPlatform.android,
    FlutterPlatform.web,
    FlutterPlatform.windows,
  ];

  /// Creates an inspector.
  const BuildArtifactsInspector();

  /// The project's app icon from whichever platform has one, or null.
  Future<String?> projectIconPath(String projectPath) async {
    for (final platform in _projectIconPlatforms) {
      final iconPath = await _appIconPath(projectPath, platform);
      if (iconPath != null) return iconPath;
    }
    return null;
  }

  /// Describes [platform]'s build output and app icon in [projectPath].
  Future<BuildArtifacts> inspect(
    String projectPath,
    FlutterPlatform platform,
  ) async {
    final buildDir = Directory(p.join(projectPath, 'build'));
    final location = await _buildLocation(buildDir, platform.name);
    return BuildArtifacts(
      appIconPath: await _appIconPath(projectPath, platform),
      location: location ?? 'No build directory found',
      size: location == null ? 'Not built' : await _size(Directory(location)),
      lastBuildTime: await _lastBuildTime(buildDir),
    );
  }

  /// First existing icon for [platform], or null.
  Future<String?> _appIconPath(
    String projectPath,
    FlutterPlatform platform,
  ) async {
    final candidates = _iconCandidates[platform];
    for (final relativePath in candidates ?? const <String>[]) {
      final iconPath = p.join(projectPath, relativePath);
      if (await File(iconPath).exists()) return iconPath;
    }
    return null;
  }

  /// `build/<platform>`, else a build entry named like the platform, else
  /// `build/` itself; null when nothing has been built.
  Future<String?> _buildLocation(Directory buildDir, String platform) async {
    if (!await buildDir.exists()) return null;

    final platformDir = Directory(p.join(buildDir.path, platform));
    if (await platformDir.exists()) return platformDir.path;

    await for (final entry in buildDir.list(followLinks: false)) {
      final name = p.basename(entry.path).toLowerCase();
      if (name.contains(platform) || platform.contains(name)) {
        return entry.path;
      }
    }
    return buildDir.path;
  }

  /// Newest modification time under [buildDir], to the second.
  Future<String> _lastBuildTime(Directory buildDir) async {
    if (!await buildDir.exists()) return 'Never';
    try {
      DateTime? latest;
      await for (final entry in buildDir.list(recursive: true)) {
        final modified = (await entry.stat()).modified;
        if (latest == null || modified.isAfter(latest)) latest = modified;
      }
      return latest?.toString().split('.').first ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Total size of the files under [directory], human readable.
  Future<String> _size(Directory directory) async {
    if (!await directory.exists()) return 'Not built';
    try {
      var totalBytes = 0;
      await for (final entry in directory.list(recursive: true)) {
        if (entry is File) totalBytes += await entry.length();
      }
      if (totalBytes == 0) return '0 B';

      var unit = 0;
      var size = totalBytes.toDouble();
      while (size > AppMetric.fileSizeDivisor && unit < _sizeUnits.length - 1) {
        size /= AppMetric.fileSizeDivisor;
        unit++;
      }
      return '${size.toStringAsFixed(1)} ${_sizeUnits[unit]}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
