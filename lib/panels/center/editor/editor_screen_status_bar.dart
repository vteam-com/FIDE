import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

/// Renders the editor status bar with cursor, search, and formatting controls.
class EditorScreenStatusBar extends StatelessWidget {
  /// Creates the editor status bar.
  const EditorScreenStatusBar({
    super.key,
    required this.showDiffView,
    required this.regionsExpanded,
    required this.currentLineNumber,
    required this.currentColumnNumber,
    required this.currentMatchIndex,
    required this.matchCount,
    required this.canFormat,
    required this.fileLanguage,
    required this.onToggleAllRegions,
    required this.onFormatFile,
  });
  final bool canFormat;
  final int currentColumnNumber;
  final int currentLineNumber;
  final int currentMatchIndex;
  final String fileLanguage;
  final int matchCount;
  final VoidCallback onFormatFile;
  final VoidCallback onToggleAllRegions;
  final bool regionsExpanded;
  final bool showDiffView;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.micro,
      ),
      child: Row(
        children: [
          if (showDiffView)
            const Text(
              'Diff View',
              style: TextStyle(fontSize: AppFontSize.caption),
            )
          else ...[
            IconButton(
              icon: Icon(
                regionsExpanded ? Icons.unfold_less : Icons.unfold_more,
                size: AppIconSize.medium,
              ),
              onPressed: onToggleAllRegions,
              tooltip: regionsExpanded
                  ? 'Collapse All Regions (Ctrl+Shift+[)'
                  : 'Expand All Regions (Ctrl+Shift+])',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppSize.compactIconButton,
                minHeight: AppSize.compactIconButton,
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            Text(
              'Ln $currentLineNumber',
              style: const TextStyle(fontSize: AppFontSize.caption),
            ),
            const SizedBox(width: AppSpacing.xLarge),
            Text(
              'Col $currentColumnNumber',
              style: const TextStyle(fontSize: AppFontSize.caption),
            ),
            if (matchCount > 0) ...[
              const SizedBox(width: AppSpacing.xLarge),
              Text(
                '${currentMatchIndex + 1} of $matchCount',
                style: const TextStyle(fontSize: AppFontSize.caption),
              ),
            ],
          ],
          const Spacer(),
          if (canFormat)
            IconButton(
              icon: const Icon(
                Icons.format_indent_increase,
                size: AppIconSize.medium,
              ),
              onPressed: onFormatFile,
              tooltip: 'Format File (Shift+Alt+F)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppSize.compactIconButton,
                minHeight: AppSize.compactIconButton,
              ),
            ),
          const SizedBox(width: AppSpacing.medium),
          Text(
            fileLanguage,
            style: const TextStyle(fontSize: AppFontSize.caption),
          ),
        ],
      ),
    );
  }
}
