import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/status_indicator.dart';
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
    this.findings,
    required this.onToggleAllRegions,
    required this.onFormatFile,
  });
  final bool canFormat;
  final int currentColumnNumber;
  final int currentLineNumber;
  final int currentMatchIndex;
  final String fileLanguage;

  /// The fCheck findings on the cursor line, with their most severe tone;
  /// none when null.
  final ({StatusTone tone, String message})? findings;
  final int matchCount;
  final VoidCallback onFormatFile;
  final VoidCallback onToggleAllRegions;
  final bool regionsExpanded;
  final bool showDiffView;
  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      isFooter: true,
      child: Row(
        children: [
          if (showDiffView)
            const Text('Diff View', style: AppTextStyle.caption)
          else ...[
            CompactIconButton(
              icon: regionsExpanded ? Icons.unfold_less : Icons.unfold_more,
              onPressed: onToggleAllRegions,
              tooltip: regionsExpanded
                  ? 'Collapse All Regions (Ctrl+Shift+[)'
                  : 'Expand All Regions (Ctrl+Shift+])',
            ),
            const SizedBox(width: AppSpacing.medium),
            Text('Ln $currentLineNumber', style: AppTextStyle.caption),
            const SizedBox(width: AppSpacing.xLarge),
            Text('Col $currentColumnNumber', style: AppTextStyle.caption),
            if (matchCount > 0) ...[
              const SizedBox(width: AppSpacing.xLarge),
              Text(
                '${currentMatchIndex + 1} of $matchCount',
                style: AppTextStyle.caption,
              ),
            ],
          ],
          Expanded(child: _findingsIndicator()),
          if (canFormat)
            CompactIconButton(
              icon: Icons.format_indent_increase,
              onPressed: onFormatFile,
              tooltip: 'Format File (Shift+Alt+F)',
            ),
          const SizedBox(width: AppSpacing.medium),
          Text(fileLanguage, style: AppTextStyle.caption),
        ],
      ),
    );
  }

  /// [findings] on one line, ellipsized, in full on hover; empty space
  /// when there are none.
  Widget _findingsIndicator() {
    final current = findings;
    if (current == null || showDiffView) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xLarge),
      child: Tooltip(
        message: current.message,
        child: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: StatusIndicator.tone(current.tone, label: current.message),
        ),
      ),
    );
  }
}
