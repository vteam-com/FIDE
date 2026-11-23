import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Renames the file or folder at [from] to [to], absolute paths in the
/// open project, the one way the project tree renames, as File Layout's
/// Move moves files: every `import`, `export` and `part` across the
/// project naming a Dart file it renames (the file, or each one in the
/// folder) points at its new path, and a tab showing a renamed file shows
/// it there.
Future<void> renameInProject(
  WidgetRef ref,
  String from,
  String to, {
  required bool isDirectory,
}) async {
  final projectPath = ref.read(currentProjectPathProvider);
  if (projectPath == null) throw StateError('No project is open');
  final paths = ProjectPaths(projectPath);
  final mover = ref.read(fileMoverProvider);
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
  final packageName = await ref
      .read(projectConfigReaderProvider)
      .packageName(projectPath);
  await ref
      .read(openDocumentsProvider.notifier)
      .applyRename(
        from,
        to,
        rename: () => ref
            .read(fileEntryServiceProvider)
            .rename(from, to, isDirectory: isDirectory),
        edit: () async => moves.isEmpty
            ? const {}
            : await mover.plan(projectPath, moves, packageName: packageName),
      );
}
