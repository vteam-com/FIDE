import 'package:fide/constants/core_constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/debouncer.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Added/removed line counts of the file at an absolute path against HEAD,
/// as the editor's tabs show them; null when the path is empty or not in a
/// Git repository.
///
/// Every open file of a repository shares one read of its changes
/// ([gitHeadChangesProvider]), read again once saves pause, and the
/// repository of each folder is looked up once ([gitRepoLocationProvider]),
/// so a save runs a couple of git processes however many files are open.
final gitDiffStatsProvider = FutureProvider.autoDispose
    .family<GitDiffStats?, String>((ref, filePath) async {
      if (filePath.isEmpty) return null;
      final location = await ref.watch(
        gitRepoLocationProvider(p.dirname(filePath)).future,
      );
      if (location == null) return null;
      final changes = await ref.watch(
        gitHeadChangesProvider(location.root).future,
      );
      return ref
          .read(gitServiceProvider)
          .diffStatsIn(changes, location, filePath);
    }, retry: (_, _) => null);

/// Where the folder at an absolute path sits in its Git repository; null
/// outside one. Read once while watched; [invalidateGitDiffStats] reads
/// it again, as after a repository is initialized.
final gitRepoLocationProvider = FutureProvider.autoDispose
    .family<GitRepoLocation?, String>(
      (ref, folder) => ref.read(gitServiceProvider).repoLocation(folder),
      retry: (_, _) => null,
    );

/// The changes against HEAD of the repository at a root path, for all its
/// files at once; read again once saves pause for
/// [AppDuration.saveBurstPause], and after Git actions.
final gitHeadChangesProvider = FutureProvider.autoDispose
    .family<GitHeadChanges, String>((ref, root) {
      final debounce = Debouncer(AppDuration.saveBurstPause);
      ref.listen(
        savedFilesRevisionProvider,
        (_, _) => debounce.run(ref.invalidateSelf),
      );
      ref.onDispose(debounce.cancel);
      return ref.read(gitServiceProvider).headChanges(root);
    }, retry: (_, _) => null);

/// Reads the editor's line counts again after Git changed the repository;
/// with [repositories], also which repository each folder is in, as after
/// one is initialized.
void invalidateGitDiffStats(Ref ref, {bool repositories = false}) {
  if (repositories) ref.invalidate(gitRepoLocationProvider);
  ref.invalidate(gitHeadChangesProvider);
}
