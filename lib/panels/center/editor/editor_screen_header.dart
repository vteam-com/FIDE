import 'package:fide/models/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/widgets/diff_counter.dart';
import 'package:fide/widgets/toggle_experience_mode.dart';
import 'package:flutter/material.dart';

/// Renders the editor header with document switching and primary editor actions.
class EditorScreenHeader extends StatelessWidget {
  /// Creates the editor header.
  const EditorScreenHeader({
    super.key,
    required this.openDocuments,
    required this.activeIndex,
    required this.currentFile,
    required this.allGitDiffStats,
    required this.isDirty,
    required this.showDiffView,
    required this.onDocumentSelected,
    required this.onToggleDiffView,
    required this.onToggleSearch,
    required this.onSave,
    required this.onClose,
  });
  final int activeIndex;
  final Map<String, GitDiffStats?> allGitDiffStats;
  final String currentFile;
  final bool isDirty;
  final VoidCallback onClose;
  final ValueChanged<int> onDocumentSelected;
  final VoidCallback onSave;
  final VoidCallback onToggleDiffView;
  final VoidCallback onToggleSearch;
  final List<DocumentState> openDocuments;
  final bool showDiffView;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: AppSpacing.medium),
        if (openDocuments.isNotEmpty)
          PopupMenuButton<int>(
            key: const Key('keyMruForFiles'),
            itemBuilder: (_ /*context*/) {
              return openDocuments.asMap().entries.map((entry) {
                final index = entry.key;
                final doc = entry.value;
                final gitStats = allGitDiffStats[doc.filePath];

                return PopupMenuItem<int>(
                  value: index,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == activeIndex)
                        const Icon(Icons.check, size: AppIconSize.mediumLarge)
                      else
                        const SizedBox(width: AppIconSize.mediumLarge),
                      const SizedBox(width: AppSpacing.medium),
                      Text(doc.fileName),
                      const SizedBox(width: AppSpacing.medium),
                      DiffCounter(gitStats: gitStats),
                    ],
                  ),
                );
              }).toList();
            },
            onSelected: onDocumentSelected,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeIndex < openDocuments.length) ...[
                  Text(
                    openDocuments[activeIndex].fileName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: AppFontSize.label,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  DiffCounter(
                    gitStats:
                        allGitDiffStats[openDocuments[activeIndex].filePath],
                  ),
                ],
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
        const Spacer(),
        if (allGitDiffStats[currentFile]?.hasChanges ?? false)
          ToggleExperienceMode(
            isAlternativeMode: showDiffView,
            primaryIcon: Icons.difference,
            alternativeIcon: Icons.edit,
            primaryTooltip: 'Show Diff View',
            alternativeTooltip: 'Back to Editor',
            onPressed: onToggleDiffView,
          ),
        const Spacer(),
        if (isDirty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xLarge,
              vertical: AppSpacing.medium,
            ),
            child: Center(
              child: Text(
                'Unsaved Changes',
                style: TextStyle(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        IconButton(
          key: const Key('keyEditorFind'),
          icon: const Icon(Icons.search),
          onPressed: showDiffView ? null : onToggleSearch,
          tooltip: 'Find (Cmd+F)',
        ),
        IconButton(
          key: const Key('keyEditorSave'),
          icon: const Icon(Icons.download),
          onPressed: isDirty ? onSave : null,
          tooltip: 'Save',
        ),
        IconButton(
          key: const Key('keyEditorClose'),
          icon: const Icon(Icons.close),
          onPressed: onClose,
          tooltip: 'Close Editor',
        ),
      ],
    );
  }
}
