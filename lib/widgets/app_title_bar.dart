// ignore_for_file:  use_build_context_synchronously

import 'dart:io';

import 'package:fide/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/utils/message_box.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

// Widgets

/// Represents `AppTitleBar`.
class AppTitleBar extends ConsumerStatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode)? onThemeChanged;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleBottomPanel;
  final VoidCallback? onToggleRightPanel;
  final bool leftPanelVisible;
  final bool bottomPanelVisible;
  final bool rightPanelVisible;
  final bool showPanelToggles;
  final Function(String)? onProjectSwitch;
  final VoidCallback? onProjectCreateComplete;
  final VoidCallback? onShowCreateProjectScreen;
  final VoidCallback? onCloseProject;

  const AppTitleBar({
    super.key,
    required this.themeMode,
    this.onThemeChanged,
    this.onToggleLeftPanel,
    this.onToggleBottomPanel,
    this.onToggleRightPanel,
    this.leftPanelVisible = true,
    this.bottomPanelVisible = true,
    this.rightPanelVisible = true,
    this.showPanelToggles = true,
    this.onProjectSwitch,
    this.onProjectCreateComplete,
    this.onShowCreateProjectScreen,
    this.onCloseProject,
  });

  @override
  ConsumerState<AppTitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends ConsumerState<AppTitleBar> {
  final Logger _logger = Logger('_TitleBarState');

  /// Toggles the window between maximised and restored states.
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
        height: AppSize.titleBarHeight,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            // Platform-specific spacing for window controls
            if (Platform.isMacOS)
              const SizedBox(
                width: AppSize.macWindowControlsSpacing,
              ), // Space for macOS traffic lights (left side)
            // Left section: Project dropdown or app title
            Consumer(
              builder: (_, ref, _) {
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

            // Center section: Panel toggle buttons (only shown when in main layout)
            if (widget.showPanelToggles)
              Expanded(child: Center(child: _buildPanelToggleButtons()))
            else
              const Spacer(),

            // Right section: Settings button
            _buildSettingsButton(),

            // Spacer to push content away from right-side window controls (Windows/Linux)
            if (!Platform.isMacOS) const Spacer(),

            // Space for Windows/Linux window controls (right side)
            if (!Platform.isMacOS)
              const SizedBox(width: AppSize.desktopWindowControlsSpacing),
          ],
        ),
      ),
    );
  }

  /// Builds the project name dropdown button that shows the active project and MRU list.
  Widget _buildProjectDropdown(
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () => _showProjectMenu(context, mruFolders, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              path.basename(currentProjectPath),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: onSurface.withValues(alpha: AppOpacity.prominent),
                fontWeight: FontWeight.w500,
                fontSize: AppFontSize.label,
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: onSurface.withValues(alpha: AppOpacity.secondaryText),
            size: AppIconSize.medium,
          ),
        ],
      ),
    );
  }

  /// Builds the centred app title text widget.
  Widget _buildAppTitle() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text(
      'The Flutter IDE',
      style: TextStyle(
        color: onSurface.withValues(alpha: AppOpacity.prominent),
        fontWeight: FontWeight.w500,
        fontSize: AppFontSize.label,
      ),
    );
  }

  /// Builds the row of icon buttons for toggling left, center, and right panels.
  Widget _buildPanelToggleButtons() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left panel toggle
        IconButton(
          key: const Key('togglePanelLeft'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_left.svg',
            width: AppIconSize.mediumLarge,
            height: AppIconSize.mediumLarge,
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
          key: const Key('togglePanelBottom'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_bottom.svg',
            width: AppIconSize.mediumLarge,
            height: AppIconSize.mediumLarge,
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
          key: const Key('togglePanelRight'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_right.svg',
            width: AppIconSize.mediumLarge,
            height: AppIconSize.mediumLarge,
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

  /// Builds the settings gear icon button in the title bar.
  Widget _buildSettingsButton() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      icon: const Icon(Icons.settings, size: AppIconSize.mediumLarge),
      onPressed: () {
        _showSettingsDialog();
      },
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        foregroundColor: onSurface.withValues(alpha: AppOpacity.prominent),
      ),
    );
  }

  /// Handles a selection from the project dropdown — opens a folder, closes the project, or switches to an MRU entry.
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
      // Close current project
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
      ref.read(selectedFileProvider.notifier).state = null;

      // Set main app state to create project
      widget.onShowCreateProjectScreen?.call();
      return;
    } else if (value == 'close_project') {
      widget.onCloseProject?.call();
    } else if (value.startsWith('remove_')) {
      final pathToRemove = value.substring(AppMetric.removePrefixLength);
      final updatedMru = List<String>.from(ref.read(mruFoldersProvider))
        ..remove(pathToRemove);
      ref.read(mruFoldersProvider.notifier).state = updatedMru;

      // Save to SharedPreferences
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setStringList('mru_folders', updatedMru);
      } catch (_) {
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

  /// Builds the popup menu items for the project dropdown, including MRU entries and actions.
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
                size: AppIconSize.medium,
              ),
              const SizedBox(width: AppSpacing.medium),
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
                const SizedBox(width: AppSpacing.tiny),
                Icon(
                  Icons.lock,
                  color: Theme.of(context).colorScheme.error,
                  size: AppIconSize.small,
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
              Icons.create_new_folder_outlined,
              size: AppIconSize.medium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.medium),
            Text(
              'Open Existing Project...',
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
              Icons.add_box_outlined,
              size: AppIconSize.medium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.medium),
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
              Icons.folder_off_outlined,
              size: AppIconSize.medium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.medium),
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

  /// Shows a positioned popup menu anchored below the project name button.
  void _showProjectMenu(
    BuildContext context,
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

  /// Opens the settings dialog for configuring app-level preferences.
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
              const SizedBox(height: AppSpacing.medium),
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
