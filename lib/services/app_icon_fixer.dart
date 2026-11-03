import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

part 'app_icon_fixer.android_icon_writer.dart';
part 'app_icon_fixer.app_icon_fix_exception.dart';
part 'app_icon_fixer.apple_icon_writer.dart';
part 'app_icon_fixer.icon_writer.dart';
part 'app_icon_fixer.linux_icon_writer.dart';
part 'app_icon_fixer.platform_icon_writer.dart';
part 'app_icon_fixer.web_icon_writer.dart';
part 'app_icon_fixer.windows_icon_writer.dart';

/// Writes a platform's app icons from one master image, and the files
/// listing them, so that fCheck's [AppIconChecker] finds nothing wrong:
/// what `flutter_launcher_icons` does, without its configuration.
class AppIconFixer {
  final ProjectConfigReader _config;

  /// Creates a fixer reading the project's pubspec with [_config].
  const AppIconFixer(this._config);

  /// The image the project's icons are best generated from: the one
  /// `flutter_launcher_icons` is configured with, else the largest PNG
  /// icon a platform already has that is not Flutter's default; null when
  /// there is none.
  Future<String?> defaultMasterPath(String projectPath) async {
    final pubspec = await _config.pubspec(projectPath);
    for (final path in pubspec?.launcherIconsImagePaths ?? const <String>[]) {
      final file = File(p.join(projectPath, path));
      if (await file.exists()) return file.path;
    }
    final report = await Isolate.run(
      () => const AppIconChecker().inspect(Directory(projectPath)),
    );
    AppIconSlot? best;
    for (final slot in report.slots) {
      final file = slot.file;
      if (file == null || file.icoSizes.isNotEmpty || slot.isFlutterDefault) {
        continue;
      }
      if (best == null || file.width > best.file!.width) best = slot;
    }
    final path = best?.filePath;
    return path == null ? null : p.join(projectPath, path);
  }

  /// Writes [platform]'s icons in the project at [projectPath] from the
  /// image at [masterPath] with its [PlatformIconWriter], off the UI
  /// thread; returns the project-relative files written.
  ///
  /// Throws [AppIconFixException] when the master can't be read or the
  /// platform lacks the file declaring its icons.
  Future<List<String>> fix(
    String projectPath,
    AppIconPlatform platform,
    String masterPath,
  ) {
    return Isolate.run(() {
      final writer = IconWriter.load(projectPath, masterPath);
      PlatformIconWriter.byPlatform[platform]!.write(writer);
      return writer.written;
    });
  }
}
