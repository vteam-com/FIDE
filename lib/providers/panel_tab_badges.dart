import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Number of files the open project's Git repository has changes in,
/// flagged on the Git tab; zero without a project or a repository.
final gitChangeCountProvider = Provider.autoDispose<int>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return 0;
  return ref.watch(
    gitRepoControllerProvider(projectPath)
        .select((repo) => repo.value?.status.changedFileCount ?? 0),
  );
});
