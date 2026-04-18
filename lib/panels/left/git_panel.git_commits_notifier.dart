part of 'git_panel.dart';

/// Represents `GitCommitsNotifier`.
class GitCommitsNotifier extends StateNotifier<AsyncValue<List<GitCommit>>> {
  GitCommitsNotifier() : super(const AsyncValue.data([]));

  final GitService _gitService = GitService();

  /// Handles `GitCommitsNotifier.loadCommits`.
  Future<void> loadCommits(
    String projectPath, {
    int count = AppMetric.gitCommitDefaultCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final commits = await _gitService.getRecentCommits(
        projectPath,
        count: count,
      );
      state = AsyncValue.data(commits);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
