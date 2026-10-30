// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:flutter/material.dart';

/// A specialized widget for displaying container/item counters using Chip
class ContainerCounter extends StatelessWidget {
  const ContainerCounter({
    super.key,
    required this.count,
    this.tooltip,
    this.onTap,
  });

  /// The count value to display
  final int count;

  /// Called when the counter is clicked; null when it isn't clickable.
  final VoidCallback? onTap;

  /// Optional tooltip for accessibility
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      label: Text(
        count.toString(),
        style: const TextStyle(fontSize: AppFontSize.badge),
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final counter = Clickable(onTap: onTap, child: chip);

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: counter);
    }

    return counter;
  }
}
