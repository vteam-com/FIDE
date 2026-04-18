// ignore_for_file: deprecated_member_use

import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

/// Represents `SearchToggleIcons`.
class SearchToggleIcons extends StatelessWidget {
  const SearchToggleIcons({
    super.key,
    required this.caseSensitive,
    required this.wholeWord,
    required this.onCaseSensitiveChanged,
    required this.onWholeWordChanged,
    this.showWholeWord = true,
  });

  final bool caseSensitive;

  final ValueChanged<bool> onCaseSensitiveChanged;

  final ValueChanged<bool> onWholeWordChanged;

  final bool showWholeWord;

  final bool wholeWord;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.xLarge,
      children: [
        IconButton(
          icon: Icon(
            caseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
            size: AppIconSize.mediumLarge,
            color: caseSensitive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
          ),
          onPressed: () => onCaseSensitiveChanged(!caseSensitive),
          tooltip: 'Toggle case sensitivity (${caseSensitive ? 'ON' : 'OFF'})',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (showWholeWord)
          IconButton(
            icon: Icon(
              wholeWord ? Icons.format_quote : Icons.format_quote_outlined,
              size: AppIconSize.mediumLarge,
              color: wholeWord
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
            ),
            onPressed: () => onWholeWordChanged(!wholeWord),
            tooltip: 'Toggle whole word matching (${wholeWord ? 'ON' : 'OFF'})',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
