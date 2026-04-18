import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// Renders the editor image preview for supported image files.
class EditorScreenImageView extends StatelessWidget {
  /// Creates the editor image preview.
  const EditorScreenImageView({
    super.key,
    required this.filePath,
    required this.documentContentLength,
  });
  final int documentContentLength;
  final String filePath;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    EditorConfig.imagePreviewMaxWidthFactor,
                maxHeight:
                    MediaQuery.of(context).size.height *
                    EditorConfig.imagePreviewMaxHeightFactor,
              ),
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, _ /* error */, _ /* stackTrace */) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: AppSize.largePreviewIcon,
                        color: Theme.of(context).colorScheme.error.withValues(
                          alpha: AppOpacity.disabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xLarge),
                      Text(
                        'Failed to load image',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        'The image file may be corrupted or unsupported',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.muted),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xLarge,
                vertical: AppSpacing.medium,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: AppOpacity.divider),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                children: [
                  Text(
                    'Image Preview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.tiny),
                  Text(
                    'Size: ${(documentContentLength / AppMetric.fileSizeDivisor).round()}KB • ${path.extension(filePath).toUpperCase().substring(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: AppOpacity.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
