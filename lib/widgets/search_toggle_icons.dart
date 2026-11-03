// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_icon_button.dart';
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
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.medium,
      children: [
        _toggle(
          on: caseSensitive,
          icon: caseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
          tooltip: 'Toggle case sensitivity',
          onChanged: onCaseSensitiveChanged,
        ),
        if (showWholeWord)
          _toggle(
            on: wholeWord,
            icon: wholeWord ? Icons.format_quote : Icons.format_quote_outlined,
            tooltip: 'Toggle whole word matching',
            onChanged: onWholeWordChanged,
          ),
      ],
    );
  }

  /// A button flipping [on], in the primary color while on.
  Widget _toggle({
    required bool on,
    required IconData icon,
    required String tooltip,
    required ValueChanged<bool> onChanged,
  }) {
    return CompactIconButton(
      icon: icon,
      selected: on,
      tooltip: '$tooltip (${on ? 'ON' : 'OFF'})',
      onPressed: () => onChanged(!on),
    );
  }
}
