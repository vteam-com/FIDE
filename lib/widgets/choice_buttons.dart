import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A compact row of joined buttons picking one of [values], each shown by
/// its [icon] and [label], small enough for a toolbar.
class ChoiceButtons<T> extends StatelessWidget {
  /// Creates the buttons for [values], [selected] highlighted.
  const ChoiceButtons({
    super.key,
    required this.values,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  /// Glyph of a value.
  final IconData Function(T value) icon;

  /// Name of a value.
  final String Function(T value) label;

  /// Called with the value picked.
  final ValueChanged<T> onSelected;

  /// The value highlighted.
  final T selected;

  /// The choices, in display order.
  final List<T> values;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        minimumSize: const Size(0, AppSize.compactTextButtonHeight),
        textStyle: AppTextStyle.caption,
        iconSize: AppIconSize.small,
      ),
      segments: [
        for (final value in values)
          ButtonSegment(
            value: value,
            icon: Icon(icon(value)),
            label: Text(label(value)),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}
