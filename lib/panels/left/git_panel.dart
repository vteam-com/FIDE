import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/widget_services/image_diff.dart';
import 'package:fide/widget_services/selected_file_builder.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/diff_counter.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The Git tab: the repository of the project at [projectPath], its
/// changes to stage, commit, push and pull, and their diffs.
class GitPanel extends ConsumerStatefulWidget {
  /// The project whose repository is shown.
  final String projectPath;

  /// Creates the panel for the project at [projectPath].
  const GitPanel({super.key, required this.projectPath});

  @override
  ConsumerState<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends ConsumerState<GitPanel> {
  /// Start of the message shown when the AI commit message fails.
  static const String _aiMessagePrefix = 'AI commit message: ';

  /// Glyph of Discard, for one file and for a whole section alike.
  static const IconData _discardIcon = Icons.undo;

  final TextEditingController _commitController = TextEditingController();
  bool _isCommitting = false;

  /// Whether Check again is reloading and fetching the repository.
  bool _isRefreshing = false;

  /// Stops the AI writing the commit message; null while it isn't.
  AiCancelToken? _messageCancel;

  /// Whether the AI is writing the commit message.
  bool get _isWritingMessage => _messageCancel != null;

  /// The repository the panel shows and acts on.
  GitRepoController get _repo =>
      ref.read(gitRepoControllerProvider(widget.projectPath).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(GitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _refresh();
    }
  }

  /// Reloads the repository and fetches from the remote, so Pull shows
  /// commits that arrived there; stops once the panel is gone, as
  /// switching tabs disposes it.
  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await _repo.refresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Runs a Git [action] on the repository and shows its [outcome] as
  /// success or failure; the repository reloads itself.
  Future<void> _runGitAction(
    Future<void> Function(GitRepoController) action,
    GitOutcome outcome,
  ) async {
    try {
      await action(_repo);
      if (mounted) {
        MessageBox.showSuccess(context, outcome.succeeded);
      }
    } on GitException catch (e) {
      if (mounted) {
        MessageBox.showError(context, e.explain(outcome.failed));
      }
    }
  }

  Future<void> _stageFiles(List<String> files) =>
      _runGitAction((repo) => repo.stage(files), GitMessages.stage);

  Future<void> _unstageFiles(List<String> files) =>
      _runGitAction((repo) => repo.unstage(files), GitMessages.unstage);

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
    return CompactIconButton(
      icon: hasPending ? pendingIcon : idleIcon,
      selected: hasPending,
      onPressed: onPressed,
      tooltip: hasPending
          ? '$label $pending commit${pending == 1 ? '' : 's'}'
          : label,
    );
  }

  /// Fills the commit message with one the AI writes from the staged
  /// changes, until [_stopWritingMessage].
  Future<void> _writeCommitMessage() async {
    final cancel = AiCancelToken();
    setState(() => _messageCancel = cancel);
    try {
      final message = await ref
          .read(gitRepoControllerProvider(widget.projectPath).notifier)
          .writeCommitMessage(cancel);
      if (mounted && message.isNotEmpty) _commitController.text = message;
    } on AiCancelledException {
      // Stopped by the user: the message stays as it was
    } catch (e) {
      if (mounted) MessageBox.showError(context, '$_aiMessagePrefix$e');
    } finally {
      if (mounted) setState(() => _messageCancel = null);
    }
  }

  /// Stops the AI writing the commit message.
  void _stopWritingMessage() => _messageCancel?.cancel();

  /// Commits the staged changes with the entered message.
  Future<void> _commit() async {
    if (_commitController.text.isEmpty) return;
    await _runCommitAction(
      (repo, message) => repo.commit(message),
      GitMessages.commit,
    );
  }

  /// Amends the last commit with the staged changes, rewording it when a
  /// message was entered.
  Future<void> _amend() => _runCommitAction(
    (repo, message) => repo.amend(message),
    GitMessages.amend,
  );

  /// Runs a commit-like [action] with the entered message, clearing the
  /// field and showing the spinner while it runs; shows its [outcome].
  Future<void> _runCommitAction(
    Future<void> Function(GitRepoController, String) action,
    GitOutcome outcome,
  ) async {
    setState(() => _isCommitting = true);
    try {
      final message = _commitController.text;
      _commitController.clear();
      await _runGitAction((repo) => action(repo, message), outcome);
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  Future<void> _push() =>
      _runGitAction((repo) => repo.push(), GitMessages.push);

  Future<void> _pull() =>
      _runGitAction((repo) => repo.pull(), GitMessages.pull);

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

    if (!confirmed || !mounted) return;

    await _runGitAction((repo) => repo.discard(files), GitMessages.discard);
  }

  /// Shows the changes to the repository-relative [filePath] since HEAD:
  /// its staged content when [staged], else its working copy.
  Future<void> _viewDiff(String filePath, {required bool staged}) async {
    final absolutePath = p.join(widget.projectPath, filePath);
    final git = ref.read(gitServiceProvider);
    final Widget diff;
    if (FileTypeUtils.isImageFile(absolutePath)) {
      final oldBytes = await git.getBytesAt(absolutePath);
      final newBytes = staged
          ? await git.getBytesAt(
              absolutePath,
              revision: GitService.indexRevision,
            )
          : await _readBytes(absolutePath);
      if (newBytes == null) return;
      diff = ImageDiff(
        path: absolutePath,
        oldBytes: oldBytes,
        newBytes: newBytes,
      );
    } else {
      final texts = await git.diffAgainstHead(absolutePath, staged: staged);
      if (texts == null) return;
      diff = SideBySideDiff(oldText: texts.oldText, newText: texts.newText);
    }
    if (!mounted) return;
    final windowSize = MediaQuery.of(context).size;
    MessageBox.showDetails(
      context,
      title: Text('Git Diff: ${p.basename(filePath)}'),
      // The diff scrolls its own lines within a fixed share of the window
      scrollable: false,
      content: SizedBox(
        width: windowSize.width * AppSize.diffDialogWidthFactor,
        height: windowSize.height * AppSize.diffDialogHeightFactor,
        child: diff,
      ),
    );
  }

  /// The bytes of the file at [path], or null when it is missing.
  Future<Uint8List?> _readBytes(String path) async {
    final reader = ref.read(fileContentReaderProvider);
    return await reader.exists(path) ? reader.readBytes(path) : null;
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(gitRepoControllerProvider(widget.projectPath))
        .when(
          loading: () => const LoadingIndicator(),
          error: (error, _) =>
              EmptyState.error(message: GitMessages.describeLoadError(error)),
          data: _buildRepo,
        );
  }

  /// The panel for the loaded [repo]: sync and commit actions above its
  /// changed files and recent commits.
  Widget _buildRepo(GitRepoState repo) {
    final status = repo.status;
    return Column(
      children: [
        // Header
        HeaderBar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.medium,
            children: [
              Row(
                children: [
                  _buildSyncButton(
                    label: 'Push',
                    pending: repo.ahead,
                    idleIcon: Icons.cloud_upload_outlined,
                    pendingIcon: Icons.cloud_upload,
                    onPressed: _push,
                  ),
                  _buildSyncButton(
                    label: 'Pull',
                    pending: repo.behind,
                    idleIcon: Icons.cloud_download_outlined,
                    pendingIcon: Icons.cloud_download,
                    onPressed: _pull,
                  ),
                  const Spacer(),
                  RefreshButton(busy: _isRefreshing, onPressed: _refresh),
                ],
              ),

              if (status.staged.isNotEmpty)
                Column(
                  spacing: AppSpacing.medium,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            _stopWritingMessage,
                      },
                      child: AppTextField(
                        controller: _commitController,
                        hintText: _isWritingMessage
                            ? 'Writing commit message… Esc to stop'
                            : 'Enter commit message...',
                        maxLines: AppMetric.aiInputMaxLines,
                        readOnly: _isWritingMessage,
                        trailing: TaskButton(
                          icon: Icons.auto_awesome,
                          tooltip: 'Write commit message with AI',
                          running: _isWritingMessage,
                          onRun: _writeCommitMessage,
                          onStop: _stopWritingMessage,
                        ),
                      ),
                    ),
                    Row(
                      spacing: AppSpacing.medium,
                      children: [
                        PrimaryButton(
                          busy: _isCommitting,
                          onPressed: _isWritingMessage ? null : _commit,
                          label: 'Commit',
                        ),
                        if (repo.canAmend)
                          SecondaryButton(
                            onPressed: _isCommitting || _isWritingMessage
                                ? null
                                : _amend,
                            label: 'Amend',
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: PanelScrollView(
            children: [
              // Staged files
              if (status.staged.isNotEmpty) ...[
                _buildFileSection(
                  'Staged Changes',
                  status.staged,
                  kindOf: (file) =>
                      status.stagedKinds[file] ?? GitFileStatus.added,
                  stats: repo.stagedStats,
                  staged: true,
                  onStage: null,
                  onUnstage: _unstageFiles,
                  canDiscard: false,
                  onDiscard: _discardChanges,
                ),
              ],

              // Unstaged files
              if (status.unstaged.isNotEmpty) ...[
                _buildFileSection(
                  'Changes',
                  status.unstaged,
                  kindOf: (file) =>
                      status.unstagedKinds[file] ?? GitFileStatus.modified,
                  stats: repo.unstagedStats,
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
                  'Untracked',
                  status.untracked,
                  kindOf: (_) => GitFileStatus.added,
                  stats: repo.unstagedStats,
                  onStage: _stageFiles,
                  onUnstage: null,
                  canDiscard: true,
                  onDiscard: _discardChanges,
                ),
              ],

              // Recent commits
              SectionPanel(
                title: 'Recent Commits',
                isExpanded:
                    true, // Recent commits should be expanded by default

                child: repo.commits.isEmpty
                    ? const EmptyLabel('No commits yet')
                    : Column(
                        children: repo.commits.map(_buildCommitTile).toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One recent commit: a solid primary-colored upload glyph marks a
  /// commit still waiting to be pushed; the subtitle gives its short hash
  /// and age, with the exact date on hover.
  Widget _buildCommitTile(GitCommit commit) {
    final primary = Theme.of(context).colorScheme.primary;
    return TreeRow(
      icon: Icon(
        commit.isUnpushed ? Icons.arrow_circle_up : Icons.commit,
        size: AppIconSize.medium,
        color: commit.isUnpushed ? primary : null,
      ),
      name: commit.message,
      nameStyle: commit.isUnpushed
          ? AppTextStyle.body.copyWith(color: primary)
          : null,
      note: commit.isUnpushed
          ? 'Not pushed yet · ${commit.date}'
          : '${commit.date}',
      trailing: [
        Text(
          '${commit.hash.substring(0, AppMetric.gitHashShortLength)}'
          ' · ${commit.date.timeAgo()}',
          style: AppTextStyle.secondary(context),
        ),
      ],
    );
  }

  /// A collapsible list of [files] titled [titleText]: each file is colored
  /// by the change [kindOf] reports and shows its +/- line counts from
  /// [stats], with the stage, unstage and discard actions that apply; its
  /// diffs show the staged content when [staged].
  Widget _buildFileSection(
    String titleText,
    List<String> files, {
    required GitFileStatus Function(String) kindOf,
    required Map<String, GitDiffStats> stats,
    bool staged = false,
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
          CompactTextButton(
            icon: Icons.add,
            onPressed: () => onStage(files),
            label: 'Stage All',
          ),
        if (onUnstage != null)
          CompactTextButton(
            icon: Icons.remove,
            onPressed: () => onUnstage(files),
            label: 'Unstage All',
          ),
        if (canDiscard && onDiscard != null)
          CompactTextButton(
            icon: _discardIcon,
            onPressed: () => onDiscard(files),
            label: 'Discard All',
          ),
      ],
    );

    // Build content widget with file list
    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: files.map((file) {
        final filePath = p.join(widget.projectPath, file);
        // Porcelain lists an untracked folder as one entry ending in '/'
        final item = FileSystemItem.fromPath(
          filePath,
          isDirectory: file.endsWith('/'),
          gitStatus: kindOf(file),
        );

        return Row(
          children: [
            Expanded(
              // Selecting a file rebuilds its row and the one it leaves,
              // not the whole list
              child: SelectedFileBuilder(
                path: item.path,
                builder: (_, isSelected) => FileNameWidget(
                  fileItem: item,
                  isSelected: isSelected,
                  showGitBadge: false,
                  showPath: true,
                  rootPath: widget.projectPath,
                  trailing: DiffCounter(gitStats: stats[file]),
                  onTap: () =>
                      ref.read(selectedFileProvider.notifier).state = item,
                ),
              ),
            ),
            CompactIconButton(
              icon: Icons.difference,
              onPressed: () => _viewDiff(file, staged: staged),
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
                icon: _discardIcon,
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
      child: contentWidget,
    );
  }

  @override
  void dispose() {
    _messageCancel?.cancel();
    _commitController.dispose();
    super.dispose();
  }
}
