// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

// Providers
import '../providers/app_providers.dart';

// Utils
import '../utils/message_box.dart';

// Widgets
import 'create_project_dialog.dart';

class TitleBar extends ConsumerStatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode)? onThemeChanged;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleBottomPanel;
  final VoidCallback? onToggleRightPanel;
  final bool leftPanelVisible;
  final bool bottomPanelVisible;
  final bool rightPanelVisible;
  final Function(String)? onProjectSwitch;

  const TitleBar({
    super.key,
    required this.themeMode,
    this.onThemeChanged,
    this.onToggleLeftPanel,
    this.onToggleBottomPanel,
    this.onToggleRightPanel,
    this.leftPanelVisible = true,
    this.bottomPanelVisible = true,
    this.rightPanelVisible = true,
    this.onProjectSwitch,
  });

  @override
  ConsumerState<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends ConsumerState<TitleBar> {
  final Logger _logger = Logger('_TitleBarState');

  Future<void> _toggleMaximize() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (e) {
      // Silently handle window manager errors
      _logger.severe('Error toggling window maximize state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _toggleMaximize,
      child: Container(
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
            // Left section: Project dropdown or app title
            Consumer(
              builder: (context, ref, child) {
                final currentProjectPath = ref.watch(
                  currentProjectPathProvider,
                );
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

            // Center section: Panel toggle buttons
            Expanded(child: Center(child: _buildPanelToggleButtons())),

            // Right section: Settings button
            _buildSettingsButton(),

            // Spacer to push content away from right-side window controls (Windows/Linux)
            if (!Platform.isMacOS) const Spacer(),

            // Space for Windows/Linux window controls (right side)
            if (!Platform.isMacOS) const SizedBox(width: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDropdown(
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    return GestureDetector(
      onTap: () =>
          _showProjectMenu(context, currentProjectPath, mruFolders, ref),
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
    );
  }

  Widget _buildAppTitle() {
    return Text(
      'The Flutter IDE',
      style: TextStyle(
        color: widget.themeMode == ThemeMode.dark
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.9),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildPanelToggleButtons() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left panel toggle
        IconButton(
          icon: SvgPicture.asset(
            'assets/toggle_panel_left.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.leftPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleLeftPanel,
          tooltip: 'Toggle Left Panel',
        ),
        // Bottom panel toggle
        IconButton(
          icon: SvgPicture.asset(
            'assets/toggle_panel_bottom.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.bottomPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleBottomPanel,
          tooltip: 'Toggle Bottom Panel',
        ),
        // Right panel toggle
        IconButton(
          icon: SvgPicture.asset(
            'assets/toggle_panel_right.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.rightPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleRightPanel,
          tooltip: 'Toggle Right Panel',
        ),
      ],
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
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
    );
  }

  Future<void> _handleDropdownSelection(String value, WidgetRef ref) async {
    final projectManager = ref.read(projectManagerProvider);

    if (value == 'add_folder') {
      // Open folder picker first
      try {
        final selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null && mounted && context.mounted) {
          // Use the onProjectSwitch callback to load with loading screen
          if (widget.onProjectSwitch != null) {
            await widget.onProjectSwitch!(selectedDirectory);
          } else {
            // Fallback to direct loading if no callback provided
            final success = await projectManager.loadProject(selectedDirectory);
            if (success) {
              await projectManager.tryReopenLastFile(selectedDirectory);
            }
          }
        }
      } catch (e) {
        if (mounted && context.mounted) {
          MessageBox.showError(context, 'Error opening folder: $e');
        }
      }
      return;
    } else if (value == 'create_project') {
      // Show create project dialog using the shared dialog
      final result = await showCreateProjectDialog(context);
      if (result != null) {
        final String projectName = result['name'] as String;
        final String parentDirectory = result['directory'] as String;

        // Use ProjectService to create the project
        final projectService = ref.read(projectServiceProvider);
        final success = await projectService.createProject(
          projectName,
          parentDirectory,
        );

        if (!success) {
          if (context.mounted) {
            MessageBox.showError(context, 'Failed to create project');
          }
        }
      }
      return;
    } else if (value == 'close_project') {
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
      ref.read(selectedFileProvider.notifier).state = null;
    } else if (value.startsWith('remove_')) {
      final pathToRemove = value.substring(7);
      final updatedMru = List<String>.from(ref.read(mruFoldersProvider))
        ..remove(pathToRemove);
      ref.read(mruFoldersProvider.notifier).state = updatedMru;

      // Save to SharedPreferences
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setStringList('mru_folders', updatedMru);
      } catch (e) {
        // Silently handle SharedPreferences errors
      }
    } else {
      // Use the callback to load project (this will set loading state)
      if (widget.onProjectSwitch != null) {
        await widget.onProjectSwitch!(value);
      } else {
        // Fallback to direct loading if no callback provided
        final success = await projectManager.loadProject(value);
        if (success) {
          await projectManager.tryReopenLastFile(value);
        }
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

    items.add(const PopupMenuDivider());

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

    return items;
  }

  void _showProjectMenu(
    BuildContext context,
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height,
      ),
      items: _buildDropdownMenuItems(mruFolders),
    ).then((value) async {
      if (value != null) {
        await _handleDropdownSelection(value, ref);
      }
    });
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
