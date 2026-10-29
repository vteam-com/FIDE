import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A check icon for the selected entry of a menu, or a same-sized gap for
/// the others so their labels line up.
class CheckMark extends StatelessWidget {
  /// Creates a check mark that shows only when [checked].
  const CheckMark({super.key, required this.checked});

  /// Whether this entry is the selected one.
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return checked
        ? const Icon(Icons.check, size: AppIconSize.mediumLarge)
        : const SizedBox(width: AppIconSize.mediumLarge);
  }
}
