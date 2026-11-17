part of 'git_service.dart';

/// The changes of a repository's working copy against HEAD, read once for
/// every file: what [GitService.diffStatsIn] answers for each open file.
class GitHeadChanges {
  /// Creates the changes from their line counts and untracked entries.
  const GitHeadChanges({required this.stats, required this.untracked});

  /// Line counts of each tracked file changed since HEAD (staged and
  /// unstaged changes together), by repository path.
  final Map<String, GitDiffStats> stats;

  /// Repository paths of the entries not in the index, ignored ones
  /// included; a wholly untracked folder is listed once, with a trailing
  /// slash.
  final Set<String> untracked;

  /// Whether the file at [repoPath] isn't in the index.
  bool isUntracked(String repoPath) {
    if (untracked.contains(repoPath)) return true;
    return untracked.any(
      (entry) =>
          entry.endsWith(GitService._directorySuffix) &&
          repoPath.startsWith(entry),
    );
  }
}
