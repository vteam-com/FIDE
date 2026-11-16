// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_toggle_button.dart';
import 'package:material_ui/material_ui.dart';

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
        CompactToggleButton(
          isOn: caseSensitive,
          icon: caseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
          tooltip: 'Toggle case sensitivity',
          onChanged: onCaseSensitiveChanged,
        ),
        if (showWholeWord)
          CompactToggleButton(
            isOn: wholeWord,
            icon: wholeWord ? Icons.format_quote : Icons.format_quote_outlined,
            tooltip: 'Toggle whole word matching',
            onChanged: onWholeWordChanged,
          ),
      ],
    );
  }
}
