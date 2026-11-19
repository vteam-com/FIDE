part of 'git_repo_controller.dart';

/// The network action a repository is running, one at a time: the Git
/// panel rings the button that runs it, whoever started it, and disables
/// the others meanwhile.
enum GitActivity {
  /// Reloading and fetching from the remote (Check again, File › Refresh
  /// Status).
  refresh,

  /// Pushing local commits.
  push,

  /// Pulling remote commits.
  pull,
}
