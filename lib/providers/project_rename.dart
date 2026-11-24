import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:path/path.dart' as p;

/// Renames the file or folder at [from] to [to], absolute paths in the
/// open project, reading providers with [read] (a `ref.read`): the one
/// way the project tree and the AI agent rename, as File Layout's Move
/// moves files. Every `import`, `export` and `part` across the project
/// naming a Dart file it renames (the file, or each one in the folder)
/// points at its new path, and a tab showing a renamed file shows it
/// there. Completes with the files it wrote, text by absolute path: each
/// renamed Dart file at its new path, and each other file whose
/// directives changed.
///
/// Throws a [StateError], changing nothing, when no project is open,
/// nothing is at [from] or something is at [to]. A missing folder of [to]
/// is created.
Future<Map<String, String>> renameInProject(
  ProviderRead read,
  String from,
  String to, {
  required bool isDirectory,
}) async {
  final projectPath = read(currentProjectPathProvider);
  if (projectPath == null) throw StateError('No project is open');
  final paths = ProjectPaths(projectPath);
  final entries = read(fileEntryServiceProvider);
  if (!entries.exists(from)) {
    throw StateError('${paths.relativeOf(from)} is gone: check again');
  }
  // A file moved onto another would replace it
  if (entries.exists(to)) {
    throw StateError('${paths.relativeOf(to)} already exists');
  }
  final mover = read(fileMoverProvider);
  final dartFiles = isDirectory
      ? [
          for (final path in await mover.listDartFiles(projectPath))
            if (p.isWithin(from, path)) path,
        ]
      : [if (p.extension(from) == ProjectFiles.dartExtension) from];
  final moves = {
    for (final path in dartFiles)
      paths.relativeOf(path): paths.relativeOf(
        path == from ? to : p.join(to, p.relative(path, from: from)),
      ),
  };
  final packageName = await read(projectConfigReaderProvider)
      .packageName(projectPath);
  return read(openDocumentsProvider.notifier).applyRename(
    from,
    to,
    rename: () => entries.rename(from, to, isDirectory: isDirectory),
    edit: () async => moves.isEmpty
        ? const {}
        : await mover.plan(projectPath, moves, packageName: packageName),
  );
}
