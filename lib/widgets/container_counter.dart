// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// A specialized widget for displaying container/item counters using Chip
class ContainerCounter extends StatelessWidget {
  const ContainerCounter({
    super.key,
    required this.count,
    this.fontSize = 10.0,
    this.tooltip,
  });

  /// The count value to display
  final int count;

  /// The font size for the count text
  final double fontSize;

  /// Optional tooltip for accessibility
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      label: Text(count.toString(), style: TextStyle(fontSize: fontSize)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }

    return chip;
  }
}
