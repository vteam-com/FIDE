import 'package:fide/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Centered "No project loaded" message for panels that need an open project.
class NoProjectPlaceholder extends StatelessWidget {
  /// Creates the placeholder.
  const NoProjectPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No project loaded',
      icon: Icons.folder_open,
    );
  }
}
