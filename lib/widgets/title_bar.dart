// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Providers
import '../providers/app_providers.dart';

// Widgets
import 'main_layout.dart';

class TitleBar extends ConsumerStatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode)? onThemeChanged;

  const TitleBar({super.key, required this.themeMode, this.onThemeChanged});

  @override
  ConsumerState<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends ConsumerState<TitleBar> {
  final GlobalKey<MainLayoutState> _mainLayoutKey =
      GlobalKey<MainLayoutState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: widget.themeMode == ThemeMode.dark
          ? const Color(0xFF323233) // VS Code dark title bar color
          : const Color(0xFFECECEC), // VS Code light title bar color
      child: Row(
        children: [
          // Platform-specific spacing for window controls
          if (Platform.isMacOS)
            const SizedBox(
              width: 80,
            ), // Space for macOS traffic lights (left side)
          // Project dropdown or app title
          Consumer(
            builder: (context, ref, child) {
              final currentProjectPath = ref.watch(currentProjectPathProvider);
              final mruFolders = ref.watch(mruFoldersProvider);

              if (currentProjectPath != null) {
                // Show project dropdown
                return _buildProjectDropdown(
                  currentProjectPath,
                  mruFolders,
                  ref,
                );
              } else {
                // Show app title when no project is loaded
                return _buildAppTitle();
              }
            },
          ),
          Spacer(),

          // Control buttons with proper theme colors
          _buildActionButtons(),

          // Spacer to push content away from right-side window controls (Windows/Linux)
          if (!Platform.isMacOS) const Spacer(),

          // Space for Windows/Linux window controls (right side)
          if (!Platform.isMacOS) const SizedBox(width: 120),
        ],
      ),
    );
  }

  Widget _buildProjectDropdown(
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    return PopupMenuButton<String>(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              path.basename(currentProjectPath),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: widget.themeMode == ThemeMode.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: widget.themeMode == ThemeMode.dark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.7),
            size: 16,
          ),
        ],
      ),
      onSelected: (value) async {
        await _handleDropdownSelection(value, ref);
      },
      itemBuilder: (context) {
        return _buildDropdownMenuItems(mruFolders);
      },
    );
  }

  Widget _buildAppTitle() {
    return Text(
      'FIDE - Flutter IDE',
      style: TextStyle(
        color: widget.themeMode == ThemeMode.dark
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.9),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.folder_open, size: 18),
          onPressed: () {
            _mainLayoutKey.currentState?.pickDirectory();
          },
          tooltip: 'Open Project',
          style: IconButton.styleFrom(
            foregroundColor: widget.themeMode == ThemeMode.dark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.save, size: 18),
          onPressed: () {
            // This will be handled by the editor screen
          },
          tooltip: 'Save',
          style: IconButton.styleFrom(
            foregroundColor: widget.themeMode == ThemeMode.dark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.visibility, size: 18),
          onPressed: () {
            _mainLayoutKey.currentState?.toggleOutlinePanel();
          },
          tooltip: 'Toggle Outline',
          style: IconButton.styleFrom(
            foregroundColor: widget.themeMode == ThemeMode.dark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, size: 18),
          onPressed: () {
            _showSettingsDialog();
          },
          tooltip: 'Settings',
          style: IconButton.styleFrom(
            foregroundColor: widget.themeMode == ThemeMode.dark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDropdownSelection(String value, WidgetRef ref) async {
    if (value == 'add_folder') {
      _mainLayoutKey.currentState?.pickDirectory();
    } else if (value == 'create_project') {
      // This would need to be implemented in MainLayout
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create project not yet implemented')),
      );
    } else if (value == 'close_project') {
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
    } else if (value.startsWith('remove_')) {
      final pathToRemove = value.substring(7);
      final updatedMru = List<String>.from(ref.read(mruFoldersProvider))
        ..remove(pathToRemove);
      ref.read(mruFoldersProvider.notifier).state = updatedMru;
    } else {
      // Load project
      final success = await _mainLayoutKey.currentState?.tryLoadProject(value);
      if (success == true) {
        ref.read(projectLoadedProvider.notifier).state = true;
        ref.read(currentProjectPathProvider.notifier).state = value;
      }
    }
  }

  List<PopupMenuEntry<String>> _buildDropdownMenuItems(
    List<String> mruFolders,
  ) {
    final items = <PopupMenuEntry<String>>[];

    // Add current MRU folders
    for (final folderPath in mruFolders) {
      final dirName = path.basename(folderPath);
      final hasAccess = Directory(folderPath).existsSync();
      items.add(
        PopupMenuItem<String>(
          value: folderPath,
          child: Row(
            children: [
              Icon(
                hasAccess ? Icons.folder : Icons.folder_off,
                color: hasAccess
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasAccess
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              if (!hasAccess) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.lock,
                  color: Theme.of(context).colorScheme.error,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (mruFolders.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    // Add action items
    items.add(
      PopupMenuItem<String>(
        value: 'add_folder',
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Open a folder ...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    items.add(
      PopupMenuItem<String>(
        value: 'create_project',
        child: Row(
          children: [
            Icon(
              Icons.create_new_folder,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Create new Project...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    items.add(
      PopupMenuItem<String>(
        value: 'close_project',
        child: Row(
          children: [
            Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Close Project',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Theme'),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.dark);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
