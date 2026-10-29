part of 'git_panel.dart';

/// Represents `GitStatusNotifier`.
class GitStatusNotifier extends StateNotifier<AsyncValue<GitStatus>> {
  GitStatusNotifier(this._gitService) : super(const AsyncValue.loading());

  final GitService _gitService;

  /// Handles `GitStatusNotifier.loadStatus`.
  Future<void> loadStatus(String projectPath) async {
    state = const AsyncValue.loading();
    try {
      final status = await _gitService.getStatus(projectPath);
      state = AsyncValue.data(status);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Re-reads the status of [projectPath] while keeping the current status
  /// on show, so background refreshes don't flash a loading state.
  Future<void> refreshStatus(String projectPath) async {
    try {
      state = AsyncValue.data(await _gitService.getStatus(projectPath));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
