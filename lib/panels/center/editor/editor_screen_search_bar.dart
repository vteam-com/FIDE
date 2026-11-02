import 'package:fide/constants/constants.dart';
import 'package:fide/panels/center/editor/editor_search_controller.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/search_replace_field.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:flutter/material.dart';

/// Renders the inline editor search and replace controls and match
/// navigation actions.
class EditorScreenSearchBar extends StatelessWidget {
  /// Creates the find bar of [controller].
  const EditorScreenSearchBar({
    super.key,
    required this.controller,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onReplaceAll,
  });

  /// The query, options, matches and replacement shown.
  final EditorSearchController controller;

  /// Selects the next match.
  final VoidCallback onNextMatch;

  /// Selects the previous match.
  final VoidCallback onPreviousMatch;

  /// Replaces every match.
  final VoidCallback onReplaceAll;

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchReplaceField(
              searchField: AppTextField(
                controller: controller.queryController,
                focusNode: controller.queryFocusNode,
                hintText: 'Find in file...',
                icon: Icons.search,
                onChanged: controller.search,
                onSubmitted: (_ /* value */) => onNextMatch(),
              ),
              searchActions: [
                SearchToggleIcons(
                  caseSensitive: controller.caseSensitive,
                  wholeWord: controller.wholeWord,
                  onCaseSensitiveChanged: controller.setCaseSensitive,
                  onWholeWordChanged: controller.setWholeWord,
                ),
                CompactIconButton(
                  icon: Icons.close,
                  onPressed: controller.close,
                  tooltip: 'Close (Esc)',
                ),
              ],
              replaceController: controller.replaceController,
              onReplace: controller.replace,
              onReplaceAll: onReplaceAll,
            ),
            const SizedBox(height: AppSpacing.tiny),
            Row(
              children: [
                const Spacer(),
                if (controller.matchCount > 0) ...[
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
                    '${controller.currentIndex + 1} of ${controller.matchCount}',
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
