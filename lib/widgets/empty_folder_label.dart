import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// Placeholder shown under an expanded folder that has no entries.
class EmptyFolderLabel extends StatelessWidget {
  /// Creates the placeholder.
  const EmptyFolderLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'empty folder',
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: AppFontSize.caption,
      ),
    );
  }
}
