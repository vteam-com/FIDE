import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as path;

part 'git_panel.git_status_notifier.dart';
part 'git_panel.git_commits_notifier.dart';

/// Represents `GitPanel`.
class GitPanel extends ConsumerStatefulWidget {
  final String projectPath;
  final Function(FileSystemItem)? onFileSelected;
  final FileSystemItem? selectedFile;

  const GitPanel({
    super.key,
    required this.projectPath,
    required this.onFileSelected,
    required this.selectedFile,
  });

  @override
  ConsumerState<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends ConsumerState<GitPanel> {
  final TextEditingController _commitController = TextEditingController();
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGitData();
    });
  }

  @override
  void didUpdateWidget(GitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _loadGitData();
    }
  }

  Future<void> _loadGitData() async {
    await ref.read(gitStatusProvider.notifier).loadStatus(widget.projectPath);
    await ref.read(gitCommitsProvider.notifier).loadCommits(widget.projectPath);
  }

  /// Runs a Git [action], shows its result message, and reloads the panel.
  Future<void> _runGitAction(Future<String> Function(GitService) action) async {
    final result = await action(ref.read(gitServiceProvider));
    if (mounted) {
      MessageBox.showInfo(context, result);
    }
    _loadGitData();
  }

  Future<void> _stageFiles(List<String> files) =>
      _runGitAction((git) => git.stageFiles(widget.projectPath, files));

  Future<void> _unstageFiles(List<String> files) =>
      _runGitAction((git) => git.unstageFiles(widget.projectPath, files));

  /// Handles `_commit`.
  Future<void> _commit() async {
    if (_commitController.text.isEmpty) return;

    setState(() => _isCommitting = true);
    try {
      final message = _commitController.text;
      _commitController.clear();
      await _runGitAction((git) => git.commit(widget.projectPath, message));
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  Future<void> _push() => _runGitAction((git) => git.push(widget.projectPath));

  Future<void> _pull() => _runGitAction((git) => git.pull(widget.projectPath));

  /// Handles `_discardChanges`.
  Future<void> _discardChanges(List<String> files) async {
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Discard Changes',
      message: files.length == 1
          ? 'Discard changes to "${files.first}"?\n\nThis action cannot be undone.'
          : 'Discard changes to ${files.length} files?\n\nThis action cannot be undone.',
      confirmLabel: 'Discard',
    );

    if (!confirmed) return;

    final gitService = ref.read(gitServiceProvider);
    final result = await gitService.discardChanges(widget.projectPath, files);
    if (mounted) {
      final isSuccess = result.contains('successfully');
      if (isSuccess) {
        MessageBox.showSuccess(context, result);
      } else {
        MessageBox.showError(context, result);
      }
    }
    _loadGitData();
  }

  /// Reads the working-directory content of [filePath], or '' when missing.
  Future<String> _readWorkingCopy(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists() ? await file.readAsString() : '';
    } catch (_) {
      return '';
    }
  }

  /// Handles `_viewDiff`.
  Future<void> _viewDiff(String filePath) async {
    final gitService = ref.read(gitServiceProvider);
    final fullFilePath = path.join(widget.projectPath, filePath);

    // Determine file status to get correct content
    final status = await gitService.getStatus(widget.projectPath);
    final isStaged = status.staged.contains(filePath);
    final isUntracked = status.untracked.contains(filePath);

    // Untracked files have no committed side; staged files compare the
    // index, everything else the working copy
    final oldText = isUntracked
        ? ''
        : await gitService.getHeadContent(fullFilePath);
    final stagedText = isStaged
        ? await gitService.getStagedContent(fullFilePath)
        : null;
    final newText = stagedText ?? await _readWorkingCopy(fullFilePath);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Git Diff: ${path.basename(filePath)}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * AppOpacity.emphasis,
            height: MediaQuery.of(context).size.height * AppOpacity.muted,
            child: SideBySideDiff(oldText: oldText, newText: newText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final gitStatus = ref.watch(gitStatusProvider);
    final gitCommits = ref.watch(gitCommitsProvider);

    return gitStatus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (status) => Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadGitData,
                      tooltip: 'Refresh',
                    ),

                    IconButton(
                      icon: const Icon(Icons.cloud_upload),
                      onPressed: _push,
                      tooltip: 'Push',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cloud_download),
                      onPressed: _pull,
                      tooltip: 'Pull',
                    ),
                  ],
                ),

                if (status.staged.isNotEmpty)
                  TextField(
                    controller: _commitController,
                    maxLines: AppMetric.aiInputMaxLines,
                    style: const TextStyle(fontSize: AppFontSize.body),
                    decoration: const InputDecoration(
                      hintText: 'Enter commit message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (status.staged.isNotEmpty)
                  ElevatedButton(
                    onPressed: _isCommitting ? null : _commit,
                    child: _isCommitting
                        ? const SizedBox(
                            width: AppIconSize.large,
                            height: AppIconSize.large,
                            child: CircularProgressIndicator(
                              strokeWidth: AppBorderWidth.medium,
                            ),
                          )
                        : const Text('Commit'),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Staged files
                  if (status.staged.isNotEmpty) ...[
                    /// Handles `_buildFileSection`.
                    _buildFileSection(
                      colorScheme,
                      BadgeStatus.success(text: 'STAGED CHANGES'),
                      status.staged,
                      onStage: null,
                      onUnstage: _unstageFiles,
                      canDiscard: false,
                      onDiscard: _discardChanges,
                    ),
                  ],

                  // Unstaged files
                  if (status.unstaged.isNotEmpty) ...[
                    _buildFileSection(
                      colorScheme,
                      BadgeStatus.warning(text: 'CHANGES'),
                      status.unstaged,
                      onStage: _stageFiles,
                      onUnstage: null,
                      canDiscard: true,
                      onDiscard: _discardChanges,
                    ),
                  ],

                  // Untracked files
                  if (status.untracked.isNotEmpty) ...[
                    _buildFileSection(
                      colorScheme,
                      BadgeStatus.neutral(text: 'UNTRACKED'),
                      status.untracked,
                      onStage: _stageFiles,
                      onUnstage: null,
                      canDiscard: true,
                      onDiscard: _discardChanges,
                    ),
                  ],

                  // Recent commits
                  const Divider(),
                  SectionPanel(
                    title: 'Recent Commits',
                    isExpanded:
                        true, // Recent commits should be expanded by default
                    headerPadding: const EdgeInsets.all(AppSpacing.medium),
                    contentPadding: const EdgeInsets.only(
                      bottom: AppSpacing.medium,
                    ),

                    child: gitCommits.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (error, _) => Text('Error: $error'),
                      data: (commits) => commits.isEmpty
                          ? const Text('No commits yet')
                          : Column(
                              children: commits
                                  .map(
                                    (commit) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.commit,
                                        size: AppIconSize.medium,
                                      ),
                                      title: Text(
                                        commit.message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        commit.hash.substring(
                                          0,
                                          AppMetric.gitHashShortLength,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handles `_buildFileSection`.
  Widget _buildFileSection(
    ColorScheme _ /* colorScheme */,
    Widget titleWidget,
    List<String> files, {
    Function(List<String>)? onStage,
    Function(List<String>)? onUnstage,
    bool canDiscard = false,
    Function(List<String>)? onDiscard,
  }) {
    // Extract title text from BadgeStatus widget
    final String titleText = titleWidget is BadgeStatus
        ? titleWidget.text
        : 'FILES';

    // Build right widget with action buttons
    final rightWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onStage != null)
          TextButton(
            onPressed: () => onStage(files),
            child: const Text('Stage All'),
          ),
        if (onUnstage != null)
          TextButton(
            onPressed: () => onUnstage(files),
            child: const Text('Unstage All'),
          ),
        if (canDiscard && onDiscard != null)
          TextButton(
            onPressed: () => onDiscard(files),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard All'),
          ),
      ],
    );

    // Build content widget with file list
    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: files.map((file) {
        final filePath = path.join(widget.projectPath, file);
        final item = FileSystemItem.fromFileSystemEntity(File(filePath));

        // Create display name with parent folder context if not a root file
        final displayItem = FileSystemItem(
          path: item.path,

          /// Handles `_getContextualFileName`.
          name: _getContextualFileName(file),
          type: item.type,

          /// Handles `_determineGitStatus`.
          gitStatus: _determineGitStatus(titleWidget, files),
        );

        final isSelected = widget.selectedFile?.path == item.path;

        return Row(
          children: [
            Expanded(
              child: FileNameWidget(
                fileItem: displayItem,
                isSelected: isSelected,
                showGitBadge: false,
                rootPath: widget.projectPath,
                onTap: () => widget.onFileSelected?.call(item),
              ),
            ),
            IconButton(
              iconSize: AppIconSize.medium,
              icon: const Icon(Icons.difference),
              onPressed: () => _viewDiff(file),
              tooltip: 'View Diff',
            ),
            if (onStage != null)
              IconButton(
                iconSize: AppIconSize.medium,
                icon: const Icon(Icons.add),
                onPressed: () => onStage([file]),
                tooltip: 'Stage',
              ),
            if (onUnstage != null)
              IconButton(
                iconSize: AppIconSize.medium,
                icon: const Icon(Icons.remove),
                onPressed: () => onUnstage([file]),
                tooltip: 'Unstage',
              ),
            if (canDiscard && onDiscard != null)
              IconButton(
                iconSize: AppIconSize.medium,
                icon: const Icon(Icons.undo, color: Colors.red),
                onPressed: () => onDiscard([file]),
                tooltip: 'Discard Changes',
              ),
          ],
        );
      }).toList(),
    );

    return SectionPanel(
      title: titleText,
      isExpanded: true, // Git file sections should be expanded by default
      rightWidget: rightWidget,
      headerPadding: const EdgeInsets.all(AppSpacing.medium),
      contentPadding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: contentWidget,
    );
  }

  /// Handles `_determineGitStatus`.
  GitFileStatus _determineGitStatus(
    Widget titleWidget,
    List<String> _ /* files */,
  ) {
    // Extract status from BadgeStatus widget text
    if (titleWidget is BadgeStatus) {
      final text = titleWidget.text.toUpperCase();
      if (text.contains('STAGED')) {
        return GitFileStatus.added;
      } else if (text.contains('CHANGES')) {
        return GitFileStatus.modified;
      } else if (text.contains('UNTRACKED')) {
        return GitFileStatus.untracked;
      }
    }
    // Fallback: determine from file lists but this shouldn't happen
    return GitFileStatus.untracked;
  }

  /// Handles `_getContextualFileName`.
  String _getContextualFileName(String filePath) {
    // Split the path into parts
    final parts = path.split(filePath);

    // If it's a root-level file (only one part), just return the filename
    if (parts.length <= 1) {
      return path.basename(filePath);
    }

    // For files deeper in the hierarchy, show the immediate parent directory + filename
    // e.g., "lib/utils/file_type_utils.dart" becomes "utils/file_type_utils.dart"
    if (parts.length >= AppMetric.minDirPathDepth) {
      return path.join(
        parts[parts.length - AppMetric.minDirPathDepth],
        parts[parts.length - 1],
      );
    }

    // Fallback
    return path.basename(filePath);
  }

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }
}

// Git status provider
final gitStatusProvider =
    StateNotifierProvider<GitStatusNotifier, AsyncValue<GitStatus>>((ref) {
      return GitStatusNotifier(ref.read(gitServiceProvider));
    });

// Git commits provider
final gitCommitsProvider =
    StateNotifierProvider<GitCommitsNotifier, AsyncValue<List<GitCommit>>>((
      ref,
    ) {
      return GitCommitsNotifier(ref.read(gitServiceProvider));
    });
