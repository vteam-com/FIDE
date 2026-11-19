import 'dart:io';
import 'dart:isolate';

import 'package:fide/models/preview_scan.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/preview_scanner.dart';

/// A Dart file of the project and its scan.
typedef PreviewFileScan = ({String path, PreviewScan scan});

/// Finds every widget preview of a project's `lib` folder, in a
/// background isolate so a large project doesn't stall the UI.
///
/// Only files mentioning `Preview` are parsed, the others can't have one.
class PreviewProjectScanner {
  /// Creates the scanner.
  const PreviewProjectScanner();

  /// The files of the project at [projectPath] that have previews, by
  /// absolute path, sorted.
  Future<List<PreviewFileScan>> scan(String projectPath) =>
      Isolate.run(() => _scanHere(projectPath));

  /// Lists `lib` and scans each Dart file mentioning
  /// [PreviewScanner.previewClass], in the calling isolate.
  static Future<List<PreviewFileScan>> _scanHere(String projectPath) async {
    final folder = ProjectPaths(projectPath).libDir;
    if (!Directory(folder).existsSync()) return const [];
    final files = <PreviewFileScan>[];
    await for (final entity in ProjectFiles.walk(
      folder,
      extension: ProjectFiles.dartExtension,
    )) {
      final content = entity.readAsStringSync();
      if (!content.contains(PreviewScanner.previewClass)) continue;
      final scan = const PreviewScanner().scan(content);
      if (scan.isPart || scan.previews.isEmpty) continue;
      files.add((path: entity.path, scan: scan));
    }
    return files..sort((a, b) => a.path.compareTo(b.path));
  }
}
