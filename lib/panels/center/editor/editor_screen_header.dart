import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widget_services/diff_counter.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/toggle_experience_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders the editor header with document switching and primary editor actions.
class EditorScreenHeader extends ConsumerWidget {
  /// Creates the editor header.
  const EditorScreenHeader({
    super.key,
    required this.openDocuments,
    required this.activeIndex,
    required this.currentFile,
    required this.isDirty,
    required this.showDiffView,
    required this.onDocumentSelected,
    required this.onToggleDiffView,
    required this.onToggleSearch,
    required this.onSave,
    required this.onClose,
  });
  final int activeIndex;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    // Watched here, as the menu builds its entries outside of build
    final diffStats = {
      for (final document in openDocuments)
        document.filePath: ref
            .watch(gitDiffStatsProvider(document.filePath))
            .value,
    };
    return Row(
      children: [
        const SizedBox(width: AppSpacing.medium),
        // Flexible so a long name or a narrow editor shortens the name
        // instead of overflowing the action buttons
        if (openDocuments.isNotEmpty)
          Flexible(
            child: PopupMenuButton<int>(
              key: const Key('keyMruForFiles'),
              initialValue: activeIndex,
              itemBuilder: (_ /*context*/) {
                return openDocuments.asMap().entries.map((entry) {
                  return PopupMenuItem<int>(
                    value: entry.key,
                    // A fixed width: menus measure their entries, which a
                    // one-line path can't report
                    child: SizedBox(
                      width: AppSize.fileMenuWidth,
                      child: _documentRow(entry.value, projectPath, diffStats),
                    ),
                  );
                }).toList();
              },
              onSelected: onDocumentSelected,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeIndex < openDocuments.length)
                    Flexible(
                      child: _documentRow(
                        openDocuments[activeIndex],
                        projectPath,
                        diffStats,
                      ),
                    ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        if (ref.watch(gitDiffStatsProvider(currentFile)).value?.hasChanges ??
            false)
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
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xLarge,
                vertical: AppSpacing.medium,
              ),
              child: Text(
                'Unsaved Changes',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AppTextStyle.caption.copyWith(
                  color: AppTheme.readable(
                    AppTheme.warningColor,
                    Theme.of(context).colorScheme,
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          key: const Key('keyEditorFind'),
          icon: const Icon(Icons.search),
          onPressed: showDiffView ? null : onToggleSearch,
          tooltip: ShortcutHelpEntry.tooltip('Find', AppShortcut.find),
        ),
        IconButton(
          key: const Key('keyEditorSave'),
          icon: const Icon(Icons.download),
          onPressed: isDirty ? onSave : null,
          tooltip: ShortcutHelpEntry.tooltip('Save', AppShortcut.save),
        ),
        IconButton(
          key: const Key('keyEditorClose'),
          icon: const Icon(Icons.close),
          onPressed: onClose,
          tooltip: ShortcutHelpEntry.tooltip(
            'Close Editor',
            AppShortcut.closeDocument,
          ),
        ),
      ],
    );
  }

  /// [document]'s file icon, path relative to [projectPath] and Git
  /// changes from [diffStats], as the picker and its entries show them.
  Widget _documentRow(
    DocumentState document,
    String? projectPath,
    Map<String, GitDiffStats?> diffStats,
  ) {
    return IconMenuRow(
      icon: null,
      leading: FileIconUtils.ofPath(document.filePath),
      label: document.fileName,
      labelWidget: PathText(
        document.filePath,
        rootPath: projectPath,
        style: AppTextStyle.label,
      ),
      trailing: DiffCounter(gitStats: diffStats[document.filePath]),
    );
  }
}
