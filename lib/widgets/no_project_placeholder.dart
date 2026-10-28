import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// Centered "No project loaded" message for panels that need an open project.
class NoProjectPlaceholder extends StatelessWidget {
  /// Creates the placeholder, optionally with a folder icon above the text.
  const NoProjectPlaceholder({super.key, this.showIcon = false});

  /// Whether to show a large folder icon above the message.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xLarge,
        children: [
          if (showIcon)
            const Icon(
              Icons.folder_open,
              size: AppIconSize.emptyState,
              color: Colors.grey,
            ),
          const Text('No project loaded', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
