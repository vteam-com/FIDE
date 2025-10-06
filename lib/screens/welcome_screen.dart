// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_providers.dart';

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
      builder: (context, ref, child) {
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

        return Stack(
          children: [
            // Main content
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: SizedBox(
                      width: 600,
                      height: constraints.maxHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Fixed content at top (centered)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              spacing: 4,
                              children: [
                                SizedBox(height: 16),
                                // App Title
                                Text(
                                  'Welcome to',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'FIDE',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -2.0,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                // Version Info
                                Text(
                                  'Version $_appVersion',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                // Subtitle
                                Text(
                                  'Flutter Integrated Developer Environment',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          // Scrollable content taking remaining space
                          Expanded(
                            child: SingleChildScrollView(
                              child: Center(
                                child: Container(
                                  width: 600,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface.withAlpha(100),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .shadow
                                            .withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    spacing: 16,
                                    children: [
                                      // Action Buttons
                                      // Open Folder Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
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
                                            elevation: 4,
                                            shadowColor: Theme.of(
                                              context,
                                            ).colorScheme.shadow,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Create Project Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
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
                                              width: 2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                      ),
                    ),
                  );
                },
              ),
            ),
            // Top left icon
            Positioned(
              top: 16,
              left: 16,
              child: SizedBox(
                height: 120,
                child: Image.asset('assets/app.png'),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildRecentProjectsList() {
    final validMruFolders = widget.mruFolders
        .where((path) => path.isNotEmpty)
        .take(5) // Limit to 5 recent projects
        .toList();

    return validMruFolders.map((path) {
      final projectName = path.split('/').last;
      final hasAccess = Directory(path).existsSync();

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          leading: Icon(
            hasAccess ? Icons.folder : Icons.folder_off,
            color: hasAccess
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 20,
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
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => widget.onRemoveMruEntry(path),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          onTap: hasAccess ? () => widget.onOpenMruProject(path) : null,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
      );
    }).toList();
  }

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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // Keep default version if loading fails
    }
  }
}
