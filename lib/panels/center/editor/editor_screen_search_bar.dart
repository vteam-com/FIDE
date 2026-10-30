import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/header_bar.dart';
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
    return HeaderBar(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    hintText: 'Find in file...',
                    icon: Icons.search,
                    onChanged: onSearchChanged,
                    onSubmitted: (_ /* value */) => onNextMatch(),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                CompactIconButton(
                  icon: Icons.close,
                  onPressed: onClose,
                  tooltip: 'Close (Esc)',
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
                  CompactIconButton(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: onPreviousMatch,
                    tooltip: 'Previous (Shift+F3)',
                  ),
                  CompactIconButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: onNextMatch,
                    tooltip: 'Next (F3)',
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Text(
                    '${currentMatchIndex + 1} of $matchCount',
                    style: AppTextStyle.caption,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
