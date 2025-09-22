// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class SearchToggleIcons extends StatelessWidget {
  final bool caseSensitive;
  final bool wholeWord;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final ValueChanged<bool> onWholeWordChanged;
  final bool showWholeWord;

  const SearchToggleIcons({
    super.key,
    required this.caseSensitive,
    required this.wholeWord,
    required this.onCaseSensitiveChanged,
    required this.onWholeWordChanged,
    this.showWholeWord = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 16,
      children: [
        IconButton(
          icon: Icon(
            caseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
            size: 18,
            color: caseSensitive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
              size: 18,
              color: wholeWord
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
