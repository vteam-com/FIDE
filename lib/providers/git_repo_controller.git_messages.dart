part of 'git_repo_controller.dart';

/// How a Git action's outcome is worded for the user: what to show when
/// it [succeeded], and the [failed] attempt a [GitException] explains.
typedef GitOutcome = ({String succeeded, String failed});

/// The user-facing wording of every Git action the Git panel, the native
/// menu and the repository controller run; the service itself only
/// reports what git said.
abstract final class GitMessages {
  /// Outcome of making the project a repository.
  static const GitOutcome initRepository = (
    succeeded: 'Git repository initialized successfully',
    failed: 'Failed to initialize Git repository',
  );

  /// Outcome of staging files.
  static const GitOutcome stage = (
    succeeded: 'Files staged successfully',
    failed: 'Failed to stage files',
  );

  /// Outcome of unstaging files.
  static const GitOutcome unstage = (
    succeeded: 'Files unstaged successfully',
    failed: 'Failed to unstage files',
  );

  /// Outcome of discarding changes.
  static const GitOutcome discard = (
    succeeded: 'Changes discarded successfully',
    failed: 'Failed to discard changes',
  );

  /// Outcome of committing.
  static const GitOutcome commit = (
    succeeded: 'Changes committed successfully',
    failed: 'Failed to commit changes',
  );

  /// Outcome of amending the last commit.
  static const GitOutcome amend = (
    succeeded: 'Last commit amended successfully',
    failed: 'Failed to amend last commit',
  );

  /// Outcome of pushing.
  static const GitOutcome push = (
    succeeded: 'Changes pushed successfully',
    failed: 'Failed to push changes',
  );

  /// Outcome of pulling.
  static const GitOutcome pull = (
    succeeded: 'Changes pulled successfully',
    failed: 'Failed to pull changes',
  );

  /// The failed attempt to read the repository's status.
  static const String statusFailed = 'Failed to get Git status';

  /// The failed attempt to read the staged diff.
  static const String stagedDiffFailed = 'Failed to get staged diff';

  /// Words [error] from loading the repository: a [GitException] as the
  /// failed status read, anything else as it describes itself.
  static String describeLoadError(Object error) =>
      error is GitException ? error.explain(statusFailed) : '$error';
}
