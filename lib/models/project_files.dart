import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_paths.dart';
import 'package:path/path.dart' as p;

/// The files of a project the user works on, leaving out tool output and
/// hidden folders and files.
class ProjectFiles {
  /// The extension of Dart files, as [walk] and [filesIn] take it.
  static const String dartExtension = '.dart';

  /// Folders left out besides hidden ones: tool output, installed
  /// dependencies and Git data.
  static const Set<String> skippedFolders = {
    ProjectPaths.buildFolder,
    '.dart_tool',
    '.git',
    'node_modules',
    'Pods',
  };

  /// Whether a folder or file named [name] is left out.
  static bool isSkipped(String name) =>
      skippedFolders.contains(name) || ProjectNode.isHiddenName(name);

  /// The files and folders under the folder [root], without going into
  /// the ones left out; throws when [root] can't be listed.
  static Stream<FileSystemEntity> entities(String root) async* {
    await for (final entity in Directory(root).list(followLinks: false)) {
      if (isSkipped(p.basename(entity.path))) continue;
      yield entity;
      if (entity is Directory) yield* entities(entity.path);
    }
  }

  /// Paths of the files directly in the folder [folder] ending with
  /// [extension], leaving out the hidden ones; none when [folder] does not
  /// exist.
  static Future<List<String>> filesIn(
    String folder, {
    required String extension,
  }) async {
    final directory = Directory(folder);
    if (!await directory.exists()) return [];
    return [
      await for (final entity in directory.list())
        if (entity is File && _isListed(entity.path, extension)) entity.path,
    ];
  }

  /// The files under the folder [root], only those ending with
  /// [extension] when given, without going into the folders left out;
  /// throws when [root] can't be listed.
  static Stream<File> walk(String root, {String? extension}) => entities(root)
      .where((entity) => entity is File && _isListed(entity.path, extension))
      .cast<File>();

  /// Paths of the files in the loaded tree under [root], in tree order.
  static List<String> under(ProjectNode root) => [
    for (final file in root.files(skip: (node) => isSkipped(node.name)))
      file.path,
  ];

  /// Whether the file at [path] is listed when looking for [extension]:
  /// it has that extension, when one is given, and isn't left out.
  static bool _isListed(String path, String? extension) =>
      !isSkipped(p.basename(path)) &&
      (extension == null || p.extension(path) == extension);
}
