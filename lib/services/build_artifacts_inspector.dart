// ignore: fcheck_secrets
import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_paths.dart';
import 'package:path/path.dart' as p;

/// Reads a project's build output and app icon for the Execute panel and
/// the project overview.
class BuildArtifactsInspector {
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
    final report = await _slots(projectPath);
    for (final platform in _projectIconPlatforms) {
      final iconPath = iconOf(report, projectPath, platform);
      if (iconPath != null) return iconPath;
    }
    return null;
  }

  /// The sharpest icon of [platform] among [report]'s slots, as an
  /// absolute path in [projectPath]; null when no slot is filled. Icons
  /// still showing Flutter's default come last.
  static String? iconOf(
    AppIconReport report,
    String projectPath,
    FlutterPlatform platform,
  ) {
    AppIconSlot? best;
    for (final slot in report.slots) {
      if (slot.platform.name != platform.name || !slot.isFilled) continue;
      final current = best;
      if (current == null ||
          (current.isFlutterDefault && !slot.isFlutterDefault) ||
          (current.isFlutterDefault == slot.isFlutterDefault &&
              slot.file!.width > current.file!.width)) {
        best = slot;
      }
    }
    final path = best?.filePath;
    return path == null ? null : p.join(projectPath, path);
  }

  /// The icon slots of the project in [projectPath], read off the UI
  /// thread, without telling Flutter's default icons.
  static Future<AppIconReport> _slots(String projectPath) => Isolate.run(
    () => const AppIconChecker().inspect(
      Directory(projectPath),
      detectFlutterDefaults: false,
    ),
  );

  /// Describes [platform]'s build output and app icon in [projectPath].
  Future<BuildArtifacts> inspect(
    String projectPath,
    FlutterPlatform platform,
  ) async {
    final buildDir = Directory(ProjectPaths(projectPath).buildDir);
    final location = await _buildLocation(buildDir, platform.name);
    return BuildArtifacts(
      appIconPath: await appIconPath(projectPath, platform),
      location: location ?? 'No build directory found',
      size: location == null ? 'Not built' : await _size(Directory(location)),
      lastBuildTime: await _lastBuildTime(buildDir),
    );
  }

  /// The sharpest app icon [platform]'s configuration names in
  /// [projectPath], or null.
  Future<String?> appIconPath(
    String projectPath,
    FlutterPlatform platform,
  ) async => iconOf(await _slots(projectPath), projectPath, platform);

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
      return totalBytes.readableSize;
    } catch (_) {
      return 'Unknown';
    }
  }
}
