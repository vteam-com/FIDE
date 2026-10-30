import 'package:fide/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Centered "No project loaded" message for panels that need an open project.
class NoProjectPlaceholder extends StatelessWidget {
  /// Creates the placeholder, optionally with a folder icon above the text.
  const NoProjectPlaceholder({super.key, this.showIcon = false});

  /// Whether to show a large folder icon above the message.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: 'No project loaded',
      icon: showIcon ? Icons.folder_open : null,
    );
  }
}
