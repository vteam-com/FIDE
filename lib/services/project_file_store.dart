import 'dart:io';

import 'package:fide/models/project_files.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:path/path.dart' as p;

/// The files of the project at [root], listed, read and written by
/// project-relative path; every path must lie inside [root].
///
/// `CodeEditAgent` edits through it, so tests give the agent an in-memory
/// store instead of a project on disk.
class ProjectFileStore {
  /// Creates the store of the project at [root], reading and writing its
  /// files with [reader].
  const ProjectFileStore(this.root, {this.reader = const FileContentReader()});

  /// Absolute path of the project.
  final String root;

  /// Reads and writes the files.
  final FileContentReader reader;

  /// The files under [folder] (relative to [root], `.` for all), relative
  /// to [root] and sorted, skipping those [ProjectFiles] ignores and
  /// stopping after [limit] of them.
  ///
  /// Throws a [FormatException] when [folder] is outside the project.
  Future<List<String>> list(String folder, {required int limit}) async {
    final files = <String>[];
    await for (final entity in Directory(
      resolve(folder),
    ).list(recursive: true)) {
      final relative = p.relative(entity.path, from: root);
      if (entity is! File || ProjectFiles.isSkippedPath(relative)) continue;
      files.add(relative);
      if (files.length >= limit) break;
    }
    return files..sort();
  }

  /// The text of the file at [path].
  ///
  /// Throws a [FormatException] when [path] is outside the project and a
  /// [FileSystemException] when the file can't be read.
  Future<String> read(String path) async => reader.read(resolve(path));

  /// The absolute path of [path], relative to [root] or absolute inside it.
  ///
  /// Throws a [FormatException] for paths outside the project.
  String resolve(String path) {
    final resolved = p.normalize(p.join(root, path));
    if (resolved != p.normalize(root) && !p.isWithin(root, resolved)) {
      throw FormatException('$path is outside the project');
    }
    return resolved;
  }

  /// Writes [content] to the file at [path], creating its folders.
  ///
  /// Throws a [FormatException] when [path] is outside the project.
  Future<void> write(String path, String content) async {
    await reader.write(resolve(path), content);
  }
}
