import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../../services/git_service.dart';
import '../../widgets/diff_viewer.dart';
import '../../models/file_system_item.dart';
import '../../widgets/filename_widget.dart';

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

  Future<void> _stageFiles(List<String> files) async {
    final gitService = GitService();
    final result = await gitService.stageFiles(widget.projectPath, files);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    _loadGitData();
  }

  Future<void> _unstageFiles(List<String> files) async {
    final gitService = GitService();
    final result = await gitService.unstageFiles(widget.projectPath, files);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    _loadGitData();
  }

  Future<void> _commit() async {
    if (_commitController.text.isEmpty) return;

    setState(() => _isCommitting = true);
    try {
      final gitService = GitService();
      final result = await gitService.commit(
        widget.projectPath,
        _commitController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
      }
      _commitController.clear();
      _loadGitData();
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  Future<void> _push() async {
    final gitService = GitService();
    final result = await gitService.push(widget.projectPath);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    _loadGitData();
  }

  Future<void> _pull() async {
    final gitService = GitService();
    final result = await gitService.pull(widget.projectPath);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    _loadGitData();
  }

  Future<void> _viewDiff(String filePath) async {
    final gitService = GitService();
    final diff = await gitService.getFileDiff(widget.projectPath, filePath);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: DiffViewer(
              diffText: diff,
              fileName: filePath,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
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
      error: (error, stack) => Center(child: Text('Error: $error')),
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
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                    _buildFileSection(
                      colorScheme,
                      'Staged Changes',
                      status.staged,
                      onStage: null,
                      onUnstage: _unstageFiles,
                    ),
                  ],

                  // Unstaged files
                  if (status.unstaged.isNotEmpty) ...[
                    _buildFileSection(
                      colorScheme,
                      'Changes',
                      status.unstaged,
                      onStage: _stageFiles,
                      onUnstage: null,
                    ),
                  ],

                  // Untracked files
                  if (status.untracked.isNotEmpty) ...[
                    _buildFileSection(
                      colorScheme,
                      'Untracked Files',
                      status.untracked,
                      onStage: _stageFiles,
                      onUnstage: null,
                    ),
                  ],

                  // Recent commits
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Commits',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        gitCommits.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stack) => Text('Error: $error'),
                          data: (commits) => commits.isEmpty
                              ? const Text('No commits yet')
                              : Column(
                                  children: commits
                                      .map(
                                        (commit) => ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.commit,
                                            size: 16,
                                          ),
                                          title: Text(
                                            commit.message,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            commit.hash.substring(0, 7),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
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

  Widget _buildFileSection(
    ColorScheme colorScheme,
    String title,
    List<String> files, {
    Function(List<String>)? onStage,
    Function(List<String>)? onUnstage,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
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
            ],
          ),
          ...files.map((file) {
            final filePath = path.join(widget.projectPath, file);
            final item = FileSystemItem.fromFileSystemEntity(File(filePath));
            // Set Git status based on the section
            if (onStage != null) {
              item.gitStatus =
                  GitFileStatus.untracked; // For untracked/staged sections
            } else if (onUnstage != null) {
              item.gitStatus = GitFileStatus.added; // For staged section
            } else {
              item.gitStatus = GitFileStatus.modified; // For unstaged section
            }
            final isSelected = widget.selectedFile?.path == item.path;

            return Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onFileSelected?.call(item),
                    child: FileNameWidget(
                      item: item,
                      isSelected: isSelected,
                      showExpansionIndicator: false,
                      showContextMenuButton: false,
                      showGitBadge: false,
                      onTap: null, // Disable FileSystemItemWidget's tap
                      onLongPress:
                          null, // Disable FileSystemItemWidget's long press
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 16,
                  icon: const Icon(Icons.difference),
                  onPressed: () => _viewDiff(file),
                  tooltip: 'View Diff',
                ),
                if (onStage != null)
                  IconButton(
                    iconSize: 16,
                    icon: const Icon(Icons.add),
                    onPressed: () => onStage([file]),
                    tooltip: 'Stage',
                  ),
                if (onUnstage != null)
                  IconButton(
                    iconSize: 16,
                    icon: const Icon(Icons.remove),
                    onPressed: () => onUnstage([file]),
                    tooltip: 'Unstage',
                  ),
              ],
            );
          }),
        ],
      ),
    );
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
      return GitStatusNotifier();
    });

class GitStatusNotifier extends StateNotifier<AsyncValue<GitStatus>> {
  GitStatusNotifier() : super(const AsyncValue.loading());

  final GitService _gitService = GitService();

  Future<void> loadStatus(String projectPath) async {
    state = const AsyncValue.loading();
    try {
      final status = await _gitService.getStatus(projectPath);
      state = AsyncValue.data(status);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshStatus(String projectPath) async {
    await loadStatus(projectPath);
  }
}

// Git commits provider
final gitCommitsProvider =
    StateNotifierProvider<GitCommitsNotifier, AsyncValue<List<GitCommit>>>((
      ref,
    ) {
      return GitCommitsNotifier();
    });

class GitCommitsNotifier extends StateNotifier<AsyncValue<List<GitCommit>>> {
  GitCommitsNotifier() : super(const AsyncValue.data([]));

  final GitService _gitService = GitService();

  Future<void> loadCommits(String projectPath, {int count = 10}) async {
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
