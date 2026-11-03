import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'git_repo_controller.git_messages.dart';
part 'git_repo_controller.git_repo_state.dart';

/// The Git state of the repository at a project path, loaded while
/// anything watches it and reloaded after saves, file changes and Git
/// actions. A folder that isn't a repository fails without retrying.
final gitRepoControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GitRepoController, GitRepoState, String>(
      GitRepoController.new,
      retry: (_, _) => null,
    );

/// Loads a repository's [GitRepoState] and runs the Git actions the Git
/// panel offers on it.
class GitRepoController extends AsyncNotifier<GitRepoState> {
  /// Creates the controller of the repository at [projectPath].
  GitRepoController(this.projectPath);

  /// Folder of the repository.
  final String projectPath;

  /// Counts reloads, so a slow one never overwrites a newer result.
  int _generation = 0;

  @override
  Future<GitRepoState> build() {
    // Files saved or changed on disk: the changes listed may be stale
    ref.listen(savedFilesRevisionProvider, (_, _) => reload());
    ref.listen(projectTreeRevisionProvider, (_, _) => reload());
    return _load(ref.read(gitServiceProvider));
  }

  /// Reads the repository again, keeping the current state on show until
  /// the new one is ready.
  Future<void> reload() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    final git = ref.read(gitServiceProvider);
    final next = await AsyncValue.guard(() => _load(git));
    if (ref.mounted && generation == _generation) state = next;
  }

  /// Reloads, then fetches from the remote and reloads again so
  /// [GitRepoState.behind] counts commits that arrived there; the fetch
  /// needs the network, so only an explicit refresh runs it.
  Future<void> refresh() async {
    await reload();
    if (!ref.mounted) return;
    if (await ref.read(gitServiceProvider).fetch(projectPath)) {
      await reload();
    }
  }

  /// Stages [files].
  Future<void> stage(List<String> files) =>
      _mutate((git) => git.stageFiles(projectPath, files));

  /// Unstages [files].
  Future<void> unstage(List<String> files) =>
      _mutate((git) => git.unstageFiles(projectPath, files));

  /// Discards the changes to [files]; untracked files are deleted.
  Future<void> discard(List<String> files) =>
      _mutate((git) => git.discardChanges(projectPath, files));

  /// Commits the staged changes with [message].
  Future<void> commit(String message) =>
      _mutate((git) => git.commit(projectPath, message));

  /// Amends the last commit with the staged changes, rewording it unless
  /// [message] is empty.
  Future<void> amend(String message) =>
      _mutate((git) => git.amend(projectPath, message));

  /// Pushes local commits.
  Future<void> push() => _mutate((git) => git.push(projectPath));

  /// Pulls remote commits.
  Future<void> pull() => _mutate((git) => git.pull(projectPath));

  /// Status, then everything derived from it, of the repository.
  Future<GitRepoState> _load(GitService git) async {
    final status = await git.getStatus(projectPath);
    final (commits, canAmend, counts, stats) = await (
      git.getRecentCommits(projectPath),
      git.canAmend(projectPath),
      git.syncCounts(projectPath),
      git.getChangeStats(projectPath, status),
    ).wait;
    return GitRepoState(
      status: status,
      commits: commits,
      stagedStats: stats.staged,
      unstagedStats: stats.unstaged,
      ahead: counts.ahead,
      behind: counts.behind,
      canAmend: canAmend,
    );
  }

  /// Runs the mutating Git [action], then reloads, also the editor's line
  /// counts, whether it succeeded or threw its [GitException].
  Future<void> _mutate(Future<void> Function(GitService) action) async {
    try {
      await action(ref.read(gitServiceProvider));
    } finally {
      if (ref.mounted) ref.invalidate(gitDiffStatsProvider);
      await reload();
    }
  }
}
