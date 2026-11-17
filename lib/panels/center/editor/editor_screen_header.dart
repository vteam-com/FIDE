import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/diff_counter.dart';
import 'package:fide/widgets/dropdown_label.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Renders the editor header with document switching and primary editor actions.
class EditorScreenHeader extends ConsumerWidget {
  /// Creates the editor header.
  const EditorScreenHeader({
    super.key,
    required this.filePaths,
    required this.activeIndex,
    required this.currentFile,
    required this.viewKind,
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

  /// Paths of the open files in tab order.
  final List<String> filePaths;
  final bool showDiffView;

  /// How the editor shows [currentFile].
  final FileViewKind viewKind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    // Watched here, as the menu builds its entries outside of build
    final diffStats = {
      for (final filePath in filePaths)
        filePath: ref.watch(gitDiffStatsProvider(filePath)).value,
    };
    final history = ref.watch(
      openDocumentsProvider.select((documents) => documents.history),
    );
    final documents = ref.read(openDocumentsProvider.notifier);
    return HeaderBar.top(
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.medium),
          CompactIconButton.header(
            key: const Key('keyEditorGoBack'),
            icon: Icons.chevron_left,
            onPressed: history.canGoBack ? documents.goBack : null,
            tooltip: ShortcutHelpEntry.tooltip('Go Back', AppShortcut.goBack),
          ),
          CompactIconButton.header(
            key: const Key('keyEditorGoForward'),
            icon: Icons.chevron_right,
            onPressed: history.canGoForward ? documents.goForward : null,
            tooltip: ShortcutHelpEntry.tooltip(
              'Go Forward',
              AppShortcut.goForward,
            ),
          ),
          // One Expanded holds the name and the unsaved note, so the space
          // they leave goes between them and the actions, which stay at the
          // right edge; Flexible so a long name or a narrow editor shortens
          // the name instead of overflowing the actions
          Expanded(
            child: Row(
              children: [
                if (filePaths.isNotEmpty)
                  Flexible(
                    child: PopupMenuButton<int>(
                      key: const Key('keyMruForFiles'),
                      initialValue: activeIndex,
                      itemBuilder: (_ /*context*/) {
                        return filePaths.asMap().entries.map((entry) {
                          return PopupMenuItem<int>(
                            value: entry.key,
                            // A fixed width: menus measure their
                            // entries, which a one-line path can't report
                            child: SizedBox(
                              width: AppSize.fileMenuWidth,
                              child: _documentRow(
                                entry.value,
                                projectPath,
                                diffStats,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      onSelected: onDocumentSelected,
                      child: DropdownLabel(
                        child: activeIndex < filePaths.length
                            ? _documentRow(
                                filePaths[activeIndex],
                                projectPath,
                                diffStats,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
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
                          color: StatusTone.warning.readableIn(
                            Theme.of(context).colorScheme,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (viewKind.hasDiffView &&
              (ref.watch(gitDiffStatsProvider(currentFile)).value?.hasChanges ??
                  false))
            CompactIconButton.header(
              key: const Key('keyEditorDiff'),
              icon: showDiffView ? Icons.edit : Icons.difference,
              tooltip: showDiffView ? 'Back to Editor' : 'Show Diff View',
              onPressed: onToggleDiffView,
            ),
          CompactIconButton.header(
            key: const Key('keyEditorFind'),
            icon: Icons.search,
            onPressed: showDiffView ? null : onToggleSearch,
            tooltip: ShortcutHelpEntry.tooltip('Find', AppShortcut.find),
          ),
          CompactIconButton.header(
            key: const Key('keyEditorSave'),
            icon: Icons.download,
            onPressed: isDirty ? onSave : null,
            tooltip: ShortcutHelpEntry.tooltip('Save', AppShortcut.save),
          ),
          CompactIconButton.header(
            key: const Key('keyEditorClose'),
            icon: Icons.close,
            onPressed: onClose,
            tooltip: ShortcutHelpEntry.tooltip(
              'Close Editor',
              AppShortcut.closeDocument,
            ),
          ),
        ],
      ),
    );
  }

  /// [filePath]'s file icon, path relative to [projectPath] and Git
  /// changes from [diffStats], as the picker and its entries show them.
  Widget _documentRow(
    String filePath,
    String? projectPath,
    Map<String, GitDiffStats?> diffStats,
  ) {
    return IconMenuRow(
      icon: null,
      leading: FileIconUtils.ofPath(filePath),
      label: p.basename(filePath),
      labelWidget: PathText(
        filePath,
        rootPath: projectPath,
        style: AppTextStyle.label,
      ),
      trailing: DiffCounter(gitStats: diffStats[filePath]),
    );
  }
}
