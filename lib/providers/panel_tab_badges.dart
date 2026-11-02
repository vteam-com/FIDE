import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Count of pending items a left panel tab flags on its header; zero for
/// tabs without a badge.
final leftPanelTabBadgeProvider = Provider.autoDispose
    .family<int, LeftPanelTab>(
      (ref, tab) => switch (tab) {
        LeftPanelTab.git => _gitChangeCount(ref),
        _ => 0,
      },
    );

/// Count of pending items a right panel tab flags on its header; zero for
/// tabs without a badge.
final rightPanelTabBadgeProvider = Provider.autoDispose
    .family<int, RightPanelTab>(
      (ref, tab) => switch (tab) {
        RightPanelTab.localize => ref.watch(stringIssueCountProvider),
        _ => 0,
      },
    );

/// Number of files the open project's Git repository has changes in; zero
/// without a project or a repository.
int _gitChangeCount(Ref ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return 0;
  return ref.watch(
    gitRepoControllerProvider(projectPath)
        .select((repo) => repo.value?.status.changedFileCount ?? 0),
  );
}
