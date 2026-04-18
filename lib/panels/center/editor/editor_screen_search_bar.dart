import 'package:fide/models/constants.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:flutter/material.dart';

/// Renders the inline editor search controls and match navigation actions.
class EditorScreenSearchBar extends StatelessWidget {
  /// Creates the editor search bar.
  const EditorScreenSearchBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.caseSensitive,
    required this.wholeWord,
    required this.currentMatchIndex,
    required this.matchCount,
    required this.onSearchChanged,
    required this.onClose,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onCaseSensitiveChanged,
    required this.onWholeWordChanged,
  });
  final bool caseSensitive;
  final int currentMatchIndex;
  final int matchCount;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final VoidCallback onClose;
  final VoidCallback onNextMatch;
  final VoidCallback onPreviousMatch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onWholeWordChanged;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool wholeWord;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: AppOpacity.disabled,
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
            width: AppSize.borderThin,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Find in file...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tiny),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.medium,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: onSearchChanged,
                  onSubmitted: (_ /* value */) => onNextMatch(),
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Close (Esc)',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Row(
            children: [
              SearchToggleIcons(
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                onCaseSensitiveChanged: onCaseSensitiveChanged,
                onWholeWordChanged: onWholeWordChanged,
              ),
              const Spacer(),
              if (matchCount > 0) ...[
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_up,
                    size: AppIconSize.mediumLarge,
                  ),
                  onPressed: onPreviousMatch,
                  tooltip: 'Previous (Shift+F3)',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: AppIconSize.mediumLarge,
                  ),
                  onPressed: onNextMatch,
                  tooltip: 'Next (F3)',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: AppSpacing.medium),
                Text(
                  '${currentMatchIndex + 1} of $matchCount',
                  style: const TextStyle(fontSize: AppFontSize.caption),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
