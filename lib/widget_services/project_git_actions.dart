import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Initialize Repository: makes the open project a Git repository, shows
/// Git's answer or error over [context], then reloads the project's Git
/// state; does nothing without a project.
Future<void> initProjectRepository(BuildContext context, WidgetRef ref) async {
  final projectPath = ref.read(currentProjectPathProvider);
  if (projectPath == null) return;
  try {
    final result = await ref
        .read(gitServiceProvider)
        .initRepository(projectPath);
    if (context.mounted) MessageBox.showSuccess(context, result);
  } on GitException catch (e) {
    if (context.mounted) MessageBox.showError(context, '$e');
  }
  refreshProjectGitStatus(ref);
}

/// Refresh Status: reads the open project's Git state again, fetching
/// from the remote; does nothing without a project.
void refreshProjectGitStatus(WidgetRef ref) {
  final projectPath = ref.read(currentProjectPathProvider);
  if (projectPath == null) return;
  ref.read(gitRepoControllerProvider(projectPath).notifier).refresh();
}
