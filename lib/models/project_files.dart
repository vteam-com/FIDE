import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:path/path.dart' as p;

/// The files of a project the user works on, leaving out tool output and
/// hidden folders and files.
class ProjectFiles {
  /// Folders left out besides hidden ones: tool output, installed
  /// dependencies and Git data.
  static const Set<String> skippedFolders = {
    'build',
    '.dart_tool',
    '.git',
    'node_modules',
    'Pods',
  };

  /// Whether a folder or file named [name] is left out.
  static bool isSkipped(String name) =>
      skippedFolders.contains(name) || name.startsWith('.');

  /// The files and folders under the folder [root], without going into
  /// the ones left out; throws when [root] can't be listed.
  static Stream<FileSystemEntity> entities(String root) async* {
    await for (final entity in Directory(root).list(followLinks: false)) {
      if (isSkipped(p.basename(entity.path))) continue;
      yield entity;
      if (entity is Directory) yield* entities(entity.path);
    }
  }

  /// The files under the folder [root], only those ending with
  /// [extension] when given, without going into the folders left out;
  /// throws when [root] can't be listed.
  static Stream<File> walk(String root, {String? extension}) =>
      entities(root)
          .where(
            (entity) =>
                entity is File &&
                (extension == null || p.extension(entity.path) == extension),
          )
          .cast<File>();

  /// Paths of the files in the loaded tree under [root], in tree order.
  static List<String> under(ProjectNode root) {
    final files = <String>[];
    void collect(ProjectNode node) {
      for (final child in node.uniqueChildren) {
        if (isSkipped(child.name)) continue;
        if (child.isDirectory) {
          collect(child);
        } else {
          files.add(child.path);
        }
      }
    }

    collect(root);
    return files;
  }
}
