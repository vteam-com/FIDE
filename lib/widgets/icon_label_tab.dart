import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A [Tab] showing [icon] above [label], or just [icon] with a tooltip when
/// there is no room for the label.
///
/// The label takes its color and weight from the enclosing [TabBar]'s theme.
class IconLabelTab extends StatelessWidget {
  /// Creates a tab for [icon] and [label].
  const IconLabelTab({
    super.key,
    required this.icon,
    required this.label,
    required this.showLabel,
    this.height,
    this.tooltip,
  });

  /// The tab's height; the [Tab] default when null.
  final double? height;

  /// The glyph drawn at the top of the tab.
  final Widget icon;

  /// The tab's name, shown under [icon] or as its tooltip.
  final String label;

  /// Whether [label] is drawn under [icon]; when false it becomes a tooltip.
  final bool showLabel;

  /// The tooltip shown when [showLabel] is false; [label] when null.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tab = Tab(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (showLabel) ...[
            const SizedBox(height: AppSpacing.tiny),
            Text(label, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
    if (showLabel) return tab;
    return Tooltip(message: tooltip ?? label, child: tab);
  }
}
