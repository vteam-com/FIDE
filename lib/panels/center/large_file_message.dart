// ignore_for_file: deprecated_member_use

import 'package:fide/constants.dart';
import 'package:flutter/material.dart';

/// Widget to display a message when a file is too large to load in the editor
class LargeFileMessage extends StatelessWidget {
  const LargeFileMessage({
    super.key,
    required this.fileName,
    required this.fileSizeMB,
  });

  final String fileName;
  final double fileSizeMB;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning,
            size: AppSize.largePreviewIcon,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            'File "$fileName" is too large to load in the editor',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'File size: ${fileSizeMB.toStringAsFixed(1)} MB',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: AppOpacity.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            'Consider using an external editor for large files',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
