import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
                errorBuilder: (_, _ /* error */, _ /* stackTrace */) =>
                    const EmptyState(
                      icon: Icons.broken_image,
                      isError: true,
                      title: 'Failed to load image',
                      message: 'The image file may be corrupted or unsupported',
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            SurfaceCard(
              child: Column(
                children: [
                  const SectionTitle('Image Preview'),
                  const SizedBox(height: AppSpacing.tiny),
                  Text(
                    'Size: ${(documentContentLength / AppMetric.fileSizeDivisor).round()}KB • ${p.extension(filePath).toUpperCase().substring(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: AppOpacity.secondaryText),
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
