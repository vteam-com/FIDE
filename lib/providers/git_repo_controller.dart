import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/debouncer.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'git_repo_controller.git_activity.dart';
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

  /// The network action running now, which every state loaded meanwhile
  /// carries.
  GitActivity? _activity;

  /// The reload running now, if any.
  Future<void>? _reloading;

  /// Whether a reload was asked for after the running one started.
  bool _reloadPending = false;

  /// Waits for saves and file changes to pause before reloading.
  final Debouncer _reloadDebounce = Debouncer(AppDuration.saveBurstPause);

  @override
  Future<GitRepoState> build() {
    // Files saved or changed on disk: the changes listed may be stale. A
    // save also updates the tree a moment later: both read Git once
    ref.listen(savedFilesRevisionProvider, (_, _) => _scheduleReload());
    ref.listen(projectTreeRevisionProvider, (_, _) => _scheduleReload());
    ref.onDispose(_reloadDebounce.cancel);
    return _load(ref.read(gitServiceProvider));
  }

  /// Reloads once saves and file changes pause for
  /// [AppDuration.saveBurstPause].
  void _scheduleReload() => _reloadDebounce.run(reload);

  /// Reads the repository again, keeping the current state on show until
  /// the new one is ready.
  ///
  /// Reloads never overlap: one asked for while another runs starts when
  /// it ends, shared by every request made meanwhile. The future completes
  /// once a reload started after the call has finished.
  Future<void> reload() {
    _reloadPending = true;
    return _reloading ??= _reloadWhilePending();
  }

  /// Reloads until no reload is pending.
  Future<void> _reloadWhilePending() async {
    try {
      while (_reloadPending && ref.mounted) {
        _reloadPending = false;
        final git = ref.read(gitServiceProvider);
        final next = await AsyncValue.guard(() => _load(git));
        if (ref.mounted) state = next;
      }
    } finally {
      _reloading = null;
    }
  }

  /// Reloads, then fetches from the remote and reloads again so
  /// [GitRepoState.behind] counts commits that arrived there; the fetch
  /// needs the network, so only an explicit refresh runs it.
  ///
  /// The editor's line counts are read again too, with which repository
  /// each file is in: the repository may just have been initialized.
  Future<void> refresh() => _run(GitActivity.refresh, () async {
    invalidateGitDiffStats(ref, repositories: true);
    await reload();
    if (!ref.mounted) return;
    if (await ref.read(gitServiceProvider).fetch(projectPath)) {
      await reload();
    }
  });

  /// A commit message the AI writes from the staged changes; empty when
  /// it writes none. Throws an `AiCancelledException` when [cancel] stops
  /// it, and a [GitException] worded for the user when the staged changes
  /// can't be read.
  Future<String> writeCommitMessage(AiCancelToken cancel) async {
    final String diff;
    try {
      diff = await ref.read(gitServiceProvider).getStagedDiff(projectPath);
    } on GitException catch (e) {
      throw GitException(GitMessages.stagedDiffFailed, e.details);
    }
    cancel.throwIfCancelled();
    return ref.read(commitMessageWriterProvider).write(diff, cancel: cancel);
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
  Future<void> push() =>
      _run(GitActivity.push, () => _mutate((git) => git.push(projectPath)));

  /// Pulls remote commits.
  Future<void> pull() =>
      _run(GitActivity.pull, () => _mutate((git) => git.pull(projectPath)));

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
      activity: _activity,
    );
  }

  /// Runs [action] as [activity], which the state shows meanwhile; does
  /// nothing while another network action runs.
  Future<void> _run(
    GitActivity activity,
    Future<void> Function() action,
  ) async {
    if (_activity != null) return;
    _showActivity(activity);
    try {
      await action();
    } finally {
      _showActivity(null);
    }
  }

  /// Marks [activity] as running, on the loaded state too.
  void _showActivity(GitActivity? activity) {
    _activity = activity;
    final current = ref.mounted ? state.value : null;
    if (current != null) state = AsyncData(current.withActivity(activity));
  }

  /// Runs the mutating Git [action], then reloads, also the editor's line
  /// counts, whether it succeeded or threw its [GitException].
  Future<void> _mutate(Future<void> Function(GitService) action) async {
    try {
      await action(ref.read(gitServiceProvider));
    } finally {
      if (ref.mounted) invalidateGitDiffStats(ref);
      await reload();
    }
  }
}
