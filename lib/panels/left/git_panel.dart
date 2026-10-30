import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/diff_counter.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

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
  bool _isWritingMessage = false;

  /// Whether the last commit is unpushed, so Amend is offered.
  bool _canAmend = false;

  /// Local commits the upstream lacks; Push stands out while any exist.
  int _ahead = 0;

  /// Upstream commits not yet pulled; Pull stands out while any exist.
  int _behind = 0;

  /// Added/removed line counts of staged files, by repository path.
  Map<String, GitDiffStats> _stagedStats = {};

  /// Added/removed line counts of unstaged and untracked files.
  Map<String, GitDiffStats> _unstagedStats = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void didUpdateWidget(GitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _refresh();
    }
  }

  /// Reloads status, recent commits, whether the last commit can be
  /// amended, and what there is to push or pull.
  Future<void> _loadGitData() async {
    await ref.read(gitStatusProvider.notifier).loadStatus(widget.projectPath);
    await ref.read(gitCommitsProvider.notifier).loadCommits(widget.projectPath);
    final git = ref.read(gitServiceProvider);
    final canAmend = await git.canAmend(widget.projectPath);
    final counts = await git.syncCounts(widget.projectPath);
    final status = ref.read(gitStatusProvider).value;
    final stats = status == null
        ? null
        : await git.getChangeStats(widget.projectPath, status);
    if (mounted) {
      setState(() {
        _stagedStats = stats?.staged ?? {};
        _unstagedStats = stats?.unstaged ?? {};
        _canAmend = canAmend;
        _ahead = counts.ahead;
        _behind = counts.behind;
      });
    }
  }

  /// Reloads the panel, then fetches from the remote and reloads again so
  /// Pull shows commits that arrived there; the fetch needs the network,
  /// so only opening the panel and Refresh run it.
  Future<void> _refresh() async {
    await _loadGitData();
    if (await ref.read(gitServiceProvider).fetch(widget.projectPath)) {
      await _loadGitData();
    }
  }

  /// Runs a Git [action], shows its success or failure, and reloads the
  /// panel.
  Future<void> _runGitAction(Future<String> Function(GitService) action) async {
    try {
      final result = await action(ref.read(gitServiceProvider));
      if (mounted) {
        MessageBox.showSuccess(context, result);
      }
    } on GitException catch (e) {
      if (mounted) {
        MessageBox.showError(context, '$e');
      }
    }
    _loadGitData();
  }

  Future<void> _stageFiles(List<String> files) =>
      _runGitAction((git) => git.stageFiles(widget.projectPath, files));

  Future<void> _unstageFiles(List<String> files) =>
      _runGitAction((git) => git.unstageFiles(widget.projectPath, files));

  /// Push or Pull: an outline [idleIcon] while there is nothing to move,
  /// a solid [pendingIcon] in the primary color while [pending] commits
  /// wait, with the count in the tooltip.
  Widget _buildSyncButton({
    required String label,
    required int pending,
    required IconData idleIcon,
    required IconData pendingIcon,
    required VoidCallback onPressed,
  }) {
    final hasPending = pending > 0;
    return IconButton(
      icon: Icon(
        hasPending ? pendingIcon : idleIcon,
        color: hasPending ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: onPressed,
      tooltip: hasPending
          ? '$label $pending commit${pending == 1 ? '' : 's'}'
          : label,
    );
  }

  /// Fills the commit message with one the AI writes from the staged
  /// changes.
  Future<void> _writeCommitMessage() async {
    setState(() => _isWritingMessage = true);
    try {
      final diff = await ref
          .read(gitServiceProvider)
          .getStagedDiff(widget.projectPath);
      final message = await ref.read(aiServiceProvider).commitMessage(diff);
      if (mounted && message.isNotEmpty) _commitController.text = message;
    } catch (e) {
      if (mounted) MessageBox.showError(context, 'AI commit message: $e');
    } finally {
      if (mounted) setState(() => _isWritingMessage = false);
    }
  }

  /// Handles `_commit`.
  Future<void> _commit() async {
    if (_commitController.text.isEmpty) return;
    await _runCommitAction(
      (git, message) => git.commit(widget.projectPath, message),
    );
  }

  /// Amends the last commit with the staged changes, rewording it when a
  /// message was entered.
  Future<void> _amend() => _runCommitAction(
    (git, message) => git.amend(widget.projectPath, message),
  );

  /// Runs a commit-like [action] with the entered message, clearing the
  /// field and showing the spinner while it runs.
  Future<void> _runCommitAction(
    Future<String> Function(GitService, String) action,
  ) async {
    setState(() => _isCommitting = true);
    try {
      final message = _commitController.text;
      _commitController.clear();
      await _runGitAction((git) => action(git, message));
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

    await _runGitAction((git) => git.discardChanges(widget.projectPath, files));
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
    final fullFilePath = p.join(widget.projectPath, filePath);

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
      MessageBox.showDetails(
        context,
        title: Text('Git Diff: ${p.basename(filePath)}'),
        // The diff scrolls its own lines within a fixed share of the window
        scrollable: false,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * AppOpacity.emphasis,
          height: MediaQuery.of(context).size.height * AppOpacity.muted,
          child: SideBySideDiff(oldText: oldText, newText: newText),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gitStatus = ref.watch(gitStatusProvider);
    final gitCommits = ref.watch(gitCommitsProvider);

    return gitStatus.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => EmptyState(message: 'Error: $error'),
      data: (status) => Column(
        children: [
          // Header
          HeaderBar(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                      tooltip: 'Refresh',
                    ),

                    _buildSyncButton(
                      label: 'Push',
                      pending: _ahead,
                      idleIcon: Icons.cloud_upload_outlined,
                      pendingIcon: Icons.cloud_upload,
                      onPressed: _push,
                    ),
                    _buildSyncButton(
                      label: 'Pull',
                      pending: _behind,
                      idleIcon: Icons.cloud_download_outlined,
                      pendingIcon: Icons.cloud_download,
                      onPressed: _pull,
                    ),
                  ],
                ),

                if (status.staged.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Column(
                      spacing: AppSpacing.medium,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _commitController,
                          hintText: 'Enter commit message...',
                          maxLines: AppMetric.aiInputMaxLines,
                          trailing: IconButton(
                            icon: _isWritingMessage
                                ? const InlineSpinner()
                                : const Icon(
                                    Icons.auto_awesome,
                                    size: AppIconSize.large,
                                  ),
                            onPressed: _isWritingMessage
                                ? null
                                : _writeCommitMessage,
                            tooltip: 'Write commit message with AI',
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _isCommitting ? null : _commit,
                              child: _isCommitting
                                  ? const InlineSpinner()
                                  : const Text('Commit'),
                            ),
                            if (_canAmend)
                              TextButton(
                                onPressed: _isCommitting ? null : _amend,
                                child: const Text('Amend'),
                              ),
                          ],
                        ),
                      ],
                    ),
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
                    _buildFileSection(
                      'STAGED CHANGES',
                      status.staged,
                      kindOf: (file) =>
                          status.stagedKinds[file] ?? GitFileStatus.added,
                      stats: _stagedStats,
                      onStage: null,
                      onUnstage: _unstageFiles,
                      canDiscard: false,
                      onDiscard: _discardChanges,
                    ),
                  ],

                  // Unstaged files
                  if (status.unstaged.isNotEmpty) ...[
                    _buildFileSection(
                      'CHANGES',
                      status.unstaged,
                      kindOf: (file) =>
                          status.unstagedKinds[file] ?? GitFileStatus.modified,
                      stats: _unstagedStats,
                      onStage: _stageFiles,
                      onUnstage: null,
                      canDiscard: true,
                      onDiscard: _discardChanges,
                    ),
                  ],

                  // Untracked files
                  if (status.untracked.isNotEmpty) ...[
                    // Untracked files are new, so they read as added
                    _buildFileSection(
                      'UNTRACKED',
                      status.untracked,
                      kindOf: (_) => GitFileStatus.added,
                      stats: _unstagedStats,
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
                      loading: () => const LoadingIndicator(),
                      error: (error, _) => EmptyState(message: 'Error: $error'),
                      data: (commits) => commits.isEmpty
                          ? const EmptyState(message: 'No commits yet')
                          : Column(
                              children: commits.map(_buildCommitTile).toList(),
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

  /// One recent commit: a solid primary-colored upload glyph marks a
  /// commit still waiting to be pushed; the subtitle gives its short hash
  /// and age, with the exact date on hover.
  Widget _buildCommitTile(GitCommit commit) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      leading: commit.isUnpushed
          ? Tooltip(
              message: 'Not pushed yet',
              child: Icon(
                Icons.arrow_circle_up,
                size: AppIconSize.medium,
                color: primary,
              ),
            )
          : const Icon(Icons.commit, size: AppIconSize.medium),
      title: Text(
        commit.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: commit.isUnpushed ? TextStyle(color: primary) : null,
      ),
      subtitle: Tooltip(
        message: '${commit.date}',
        waitDuration: AppDuration.tooltipWait,
        child: Text(
          '${commit.hash.substring(0, AppMetric.gitHashShortLength)}'
          ' · ${commit.date.timeAgo()}',
        ),
      ),
    );
  }

  /// A collapsible list of [files] titled [titleText]: each file is colored
  /// by the change [kindOf] reports and shows its +/- line counts from
  /// [stats], with the stage, unstage and discard actions that apply.
  Widget _buildFileSection(
    String titleText,
    List<String> files, {
    required GitFileStatus Function(String) kindOf,
    required Map<String, GitDiffStats> stats,
    Function(List<String>)? onStage,
    Function(List<String>)? onUnstage,
    bool canDiscard = false,
    Function(List<String>)? onDiscard,
  }) {
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
        final filePath = p.join(widget.projectPath, file);
        final item = FileSystemItem.fromFileSystemEntity(File(filePath));

        // Create display name with parent folder context if not a root file
        final displayItem = FileSystemItem(
          path: item.path,

          name: _getContextualFileName(file),
          type: item.type,
          gitStatus: kindOf(file),
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
                trailing: DiffCounter(gitStats: stats[file]),
                onTap: () => widget.onFileSelected?.call(item),
              ),
            ),
            CompactIconButton(
              icon: Icons.difference,
              onPressed: () => _viewDiff(file),
              tooltip: 'View Diff',
            ),
            if (onStage != null)
              CompactIconButton(
                icon: Icons.add,
                onPressed: () => onStage([file]),
                tooltip: 'Stage',
              ),
            if (onUnstage != null)
              CompactIconButton(
                icon: Icons.remove,
                onPressed: () => onUnstage([file]),
                tooltip: 'Unstage',
              ),
            if (canDiscard && onDiscard != null)
              CompactIconButton(
                icon: Icons.undo,
                color: AppTheme.errorColor,
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

  /// Handles `_getContextualFileName`.
  String _getContextualFileName(String filePath) {
    // Split the path into parts
    final parts = p.split(filePath);

    // If it's a root-level file (only one part), just return the filename
    if (parts.length <= 1) {
      return p.basename(filePath);
    }

    // For files deeper in the hierarchy, show the immediate parent directory + filename
    // e.g., "lib/utils/file_type_utils.dart" becomes "utils/file_type_utils.dart"
    if (parts.length >= AppMetric.minDirPathDepth) {
      return p.join(
        parts[parts.length - AppMetric.minDirPathDepth],
        parts[parts.length - 1],
      );
    }

    // Fallback
    return p.basename(filePath);
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
