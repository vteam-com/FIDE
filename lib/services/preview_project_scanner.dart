import 'dart:io';
import 'dart:isolate';

import 'package:fide/models/preview_scan.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:path/path.dart' as p;

/// A Dart file of the project and its scan.
typedef PreviewFileScan = ({String path, PreviewScan scan});

/// Finds every widget preview of a project's `lib` folder, in a
/// background isolate so a large project doesn't stall the UI.
///
/// Only files mentioning `Preview` are parsed, the others can't have one.
class PreviewProjectScanner {
  /// Creates the scanner.
  const PreviewProjectScanner();

  /// The folder scanned, relative to the project.
  static const String _folder = 'lib';

  /// The word every preview annotation contains.
  static const String _marker = 'Preview';

  /// The files of the project at [projectPath] that have previews, by
  /// absolute path, sorted.
  Future<List<PreviewFileScan>> scan(String projectPath) =>
      Isolate.run(() => _scanSync(projectPath));

  /// Lists `lib` and scans each Dart file mentioning [_marker], in the
  /// calling isolate.
  static List<PreviewFileScan> _scanSync(String projectPath) {
    final folder = Directory(p.join(projectPath, _folder));
    if (!folder.existsSync()) return const [];
    final files = <PreviewFileScan>[];
    for (final entity in folder.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != '.dart') continue;
      final relative = p.relative(entity.path, from: projectPath);
      if (ProjectFiles.isSkippedPath(relative)) continue;
      final content = entity.readAsStringSync();
      if (!content.contains(_marker)) continue;
      final scan = const PreviewScanner().scan(content);
      if (scan.isPart || scan.previews.isEmpty) continue;
      files.add((path: entity.path, scan: scan));
    }
    return files..sort((a, b) => a.path.compareTo(b.path));
  }
}
