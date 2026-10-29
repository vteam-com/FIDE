import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// Placeholder shown under an expanded folder that has no entries.
class EmptyFolderLabel extends StatelessWidget {
  /// Creates the placeholder.
  const EmptyFolderLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'empty folder',
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.grey,
        fontSize: AppFontSize.caption,
      ),
    );
  }
}
