// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/models/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Represents `WelcomeScreen`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onOpenFolder,
    required this.onCreateProject,
    required this.mruFolders,
    required this.onOpenMruProject,
    required this.onRemoveMruEntry,
  });

  final List<String> mruFolders;

  final VoidCallback onCreateProject;

  final VoidCallback onOpenFolder;

  final Function(String) onOpenMruProject;

  final Function(String) onRemoveMruEntry;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Watch for project creation errors
        final projectCreationError = ref.watch(projectCreationErrorProvider);

        // Show error dialog if there's an error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (projectCreationError != null) {
            _showErrorDialog(context, projectCreationError);
            // Clear the error after showing
            ref.read(projectCreationErrorProvider.notifier).state = null;
          }
        });

        return Container(
          padding: const EdgeInsets.all(AppSize.compactActionButton),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: AppOpacity.divider),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: AppSpacing.xLarge,
                children: [
                  // Fixed content at top (centered)
                  Row(
                    spacing: AppSize.compactActionButton,
                    children: [
                      HeroTitleWidget(
                        title: 'Welcome to FIDE',
                        subTitle: 'Flutter Integrated Developer Environment',
                      ),
                      // Version Info
                      Text(
                        'Version\n$_appVersion',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.disabled),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  // Scrollable content taking remaining space
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: Container(
                          width: AppSize.welcomeContentWidth,
                          padding: const EdgeInsets.all(AppIconSize.xLarge),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface
                                .withAlpha(AppSize.gutterDividerAlpha.toInt()),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.xLarge,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow
                                    .withValues(alpha: AppOpacity.subtle),
                                blurRadius: AppSpacing.regular,
                                offset: const Offset(0, AppSpacing.tiny),
                              ),
                            ],
                          ),
                          child: Column(
                            spacing: AppSpacing.xLarge,
                            children: [
                              // Action Buttons
                              // Open Folder Button
                              SizedBox(
                                width: double.infinity,
                                height: AppSize.largeActionButtonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: widget.onOpenFolder,
                                  icon: Icon(
                                    Icons.folder_open,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    'Open Flutter Project',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    elevation: AppSpacing.tiny,
                                    shadowColor: Theme.of(
                                      context,
                                    ).colorScheme.shadow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.large,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Create Project Button
                              SizedBox(
                                width: double.infinity,
                                height: AppSize.largeActionButtonHeight,
                                child: OutlinedButton.icon(
                                  onPressed: widget.onCreateProject,
                                  icon: Icon(
                                    Icons.add,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  label: Text(
                                    'Create New Project',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: AppBorderWidth.medium,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.large,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Recent Projects Section
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildRecentProjectsList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the list of recent project tiles from [mruFolders], limited to the most recent entries.
  List<Widget> _buildRecentProjectsList() {
    final validMruFolders = widget.mruFolders
        .where((path) => path.isNotEmpty)
        .take(AppMetric.mruFolderLimit) // Limit to configured recent projects
        .toList();

    return validMruFolders.map((path) {
      final projectName = path.split('/').last;
      final hasAccess = Directory(path).existsSync();

      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: AppOpacity.disabled),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
          ),
        ),
        child: ListTile(
          leading: Icon(
            hasAccess ? Icons.folder : Icons.folder_off,
            color: hasAccess
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: AppIconSize.large,
          ),
          title: Text(
            projectName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasAccess
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.error,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            path,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.close,
              size: AppIconSize.medium,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => widget.onRemoveMruEntry(path),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          onTap: hasAccess ? () => widget.onOpenMruProject(path) : null,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xLarge,
            vertical: AppSpacing.tiny,
          ),
        ),
      );
    }).toList();
  }

  /// Fetches the app version from the package info plugin and stores it in [_appVersion].
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {
      // Keep default version if loading fails
    }
  }

  /// Shows an alert dialog describing a project creation error.
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Project Creation Error'),
          content: SingleChildScrollView(child: Text(errorMessage)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
