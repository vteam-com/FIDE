import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The chevron of a collapsible entry: down while expanded, right while
/// collapsed.
class ExpansionChevron extends StatelessWidget {
  /// Creates the chevron of an entry [isExpanded], in [color] or the
  /// icon theme's.
  const ExpansionChevron({super.key, required this.isExpanded, this.color});

  /// The chevron's color; the icon theme's when null.
  final Color? color;

  /// Whether the entry is expanded.
  final bool isExpanded;
  @override
  Widget build(BuildContext context) =>
      Icon(iconFor(isExpanded), size: AppIconSize.medium, color: color);

  /// The chevron's glyph for an entry [isExpanded], for buttons that take
  /// an icon.
  static IconData iconFor(bool isExpanded) =>
      isExpanded ? Icons.expand_more : Icons.chevron_right;
}
