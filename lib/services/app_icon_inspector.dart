import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/app_icon_review.dart';
import 'package:path/path.dart' as p;

/// Checks a project's app icons with fCheck's [fcheck.AppIconChecker], on a
/// background isolate; the seam tests replace to skip the disk.
class AppIconInspector {
  /// Creates a stateless inspector.
  const AppIconInspector();

  /// What the App Icons view shows for the project at [projectPath]: the
  /// platforms it has a folder for, their slots and problems, and the
  /// master image at [masterPath] when there is one.
  Future<AppIconReview> review(String projectPath, {String? masterPath}) {
    return Isolate.run(() {
      final report = const fcheck.AppIconChecker().inspect(
        Directory(projectPath),
      );
      final image = masterPath == null
          ? null
          : fcheck.AppIconFileInfo.read(File(masterPath));
      return AppIconReview.fromReport(
        report,
        projectPath: projectPath,
        presentPlatforms: {
          for (final platform in fcheck.AppIconPlatform.values)
            if (Directory(p.join(projectPath, platform.name)).existsSync())
              platform.name,
        },
        master: masterPath == null
            ? null
            : AppIconMaster(
                masterPath,
                width: image?.width,
                height: image?.height,
              ),
      );
    });
  }
}
