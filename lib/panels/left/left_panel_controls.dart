// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeftPanelControls extends ConsumerWidget {
  final bool isFilesystemMode;
  final bool isOrganizedMode;
  final bool isGitMode;
  final VoidCallback onToggleFilesystem;
  final VoidCallback onToggleOrganized;
  final VoidCallback onToggleGitPanel;

  const LeftPanelControls({
    super.key,
    required this.isGitMode,
    required this.isFilesystemMode,
    required this.isOrganizedMode,
    required this.onToggleFilesystem,
    required this.onToggleOrganized,
    required this.onToggleGitPanel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Normal File View Button
        _buildToggleButton(
          context,
          icon: Icons.folder,
          tooltip: 'Normal File View',
          isSelected: isFilesystemMode,
          onPressed: onToggleFilesystem,
        ),
        const SizedBox(width: 4),
        // Organized File View Button
        _buildToggleButton(
          context,
          icon: Icons.folder_special,
          tooltip: 'Organized File View',
          isSelected: isOrganizedMode,
          onPressed: onToggleOrganized,
        ),
        const SizedBox(width: 4),
        // Git Panel Button
        _buildToggleButton(
          context,
          icon: Icons.account_tree,
          tooltip: 'Git Panel',
          isSelected: isGitMode,
          onPressed: onToggleGitPanel,
        ),
      ],
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : Colors.transparent,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}
