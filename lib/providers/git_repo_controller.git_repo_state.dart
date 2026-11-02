part of 'git_repo_controller.dart';

/// What the Git panel shows of a repository: its changes, their line
/// counts, recent commits, and what can be pushed, pulled or amended.
class GitRepoState {
  /// Creates the state of a repository.
  const GitRepoState({
    required this.status,
    required this.commits,
    required this.stagedStats,
    required this.unstagedStats,
    required this.ahead,
    required this.behind,
    required this.canAmend,
  });

  /// Staged, unstaged and untracked files.
  final GitStatus status;

  /// Recent commits, newest first.
  final List<GitCommit> commits;

  /// Added/removed line counts of staged files, by repository path.
  final Map<String, GitDiffStats> stagedStats;

  /// Added/removed line counts of unstaged and untracked files, by
  /// repository path.
  final Map<String, GitDiffStats> unstagedStats;

  /// Local commits the upstream lacks, waiting to be pushed.
  final int ahead;

  /// Upstream commits not yet pulled.
  final int behind;

  /// Whether the last commit is unpushed, so it can be amended.
  final bool canAmend;
}
