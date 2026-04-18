import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the placeholder shown for unsupported file types.
class EditorScreenUnsupportedFileView extends StatelessWidget {
  /// Creates the unsupported-file placeholder.
  const EditorScreenUnsupportedFileView({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    final extension = filePath.split('.').last.toLowerCase();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: AppSize.largePreviewIcon,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: AppOpacity.disabled),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: AppOpacity.secondaryText,
                ),
              ),
              children: [
                const TextSpan(text: 'The file type '),
                TextSpan(
                  text: '.${extension.toUpperCase()}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' is not yet supported'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xLarge),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: AppOpacity.divider,
              ),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              children: [
                Text(
                  'Request this feature at',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.tiny),
                InkWell(
                  onTap: () async {
                    const urlString =
                        'https://github.com/vteam-com/FIDE/issues';

                    try {
                      final url = Uri.parse(urlString);
                      if (Platform.isMacOS) {
                        await launchUrl(url, mode: LaunchMode.platformDefault);
                      } else {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    } catch (_) {
                      try {
                        final url = Uri.parse(urlString);
                        await launchUrl(url, mode: LaunchMode.platformDefault);
                      } catch (fallbackError) {
                        if (context.mounted) {
                          MessageBox.showError(
                            context,
                            'Could not open link: $urlString ${fallbackError.toString()}',
                            showCopyButton: true,
                          );
                        }
                      }
                    }
                  },
                  child: Text(
                    'github.com/vteam-com/FIDE/issues',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppIconSize.xLarge),
          Text(
            'Currently supported: Most text files including\n'
            'programming languages, web files, configs, scripts, and images',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: AppOpacity.disabled),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
