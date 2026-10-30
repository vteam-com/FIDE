// ignore_for_file:  use_build_context_synchronously

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_menu_action.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/theme_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
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
  final Future<bool> Function(String directoryPath) onProjectSwitch;
  final VoidCallback onOpenFolder;
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
    required this.onProjectSwitch,
    required this.onOpenFolder,
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
        // Transparent so the window's workspace gradient runs behind it
        color: Colors.transparent,
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

    return Clickable(
      onTap: () => _showProjectMenu(context, mruFolders, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              p.basename(currentProjectPath),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTextStyle.label,
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
    return Text('The Flutter IDE', style: AppTextStyle.label);
  }

  /// Builds the row of icon buttons for toggling left, center, and right panels.
  Widget _buildPanelToggleButtons() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _panelToggle(
          'Left',
          'left',
          widget.leftPanelVisible,
          widget.onToggleLeftPanel,
          colorScheme,
        ),
        _panelToggle(
          'Bottom',
          'bottom',
          widget.bottomPanelVisible,
          widget.onToggleBottomPanel,
          colorScheme,
        ),
        _panelToggle(
          'Right',
          'right',
          widget.rightPanelVisible,
          widget.onToggleRightPanel,
          colorScheme,
        ),
      ],
    );
  }

  /// The toggle for the [label] panel, whose asset and key use [side];
  /// highlighted while [visible].
  Widget _panelToggle(
    String label,
    String side,
    bool visible,
    VoidCallback? onPressed,
    ColorScheme colorScheme,
  ) {
    return IconButton(
      key: Key('togglePanel$label'),
      icon: SvgPicture.asset(
        'assets/toggle_panel_$side.svg',
        width: AppIconSize.mediumLarge,
        height: AppIconSize.mediumLarge,
        colorFilter: ColorFilter.mode(
          visible ? colorScheme.primary : colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      ),
      onPressed: onPressed,
      tooltip: 'Toggle $label Panel',
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

  /// Runs the project menu's chosen [action]; [folder] is the project to
  /// switch to.
  Future<void> _handleDropdownSelection(
    ProjectMenuAction action,
    String? folder,
    WidgetRef ref,
  ) async {
    switch (action) {
      case ProjectMenuAction.openFolder:
        widget.onOpenFolder();
      case ProjectMenuAction.createProject:
        ref.read(projectManagerProvider).unloadProject();
        widget.onShowCreateProjectScreen?.call();
      case ProjectMenuAction.closeProject:
        widget.onCloseProject?.call();
      case ProjectMenuAction.switchProject:
        if (folder != null) await widget.onProjectSwitch(folder);
    }
  }

  /// The project menu: recent projects ([accessible] ones openable), then
  /// the open, create and close actions.
  List<PopupMenuEntry<(ProjectMenuAction, String?)>> _buildDropdownMenuItems(
    List<String> mruFolders,
    Set<String> accessible,
  ) {
    PopupMenuItem<(ProjectMenuAction, String?)> action(
      ProjectMenuAction value,
      IconData icon,
      String label,
    ) {
      return PopupMenuItem(
        value: (value, null),
        child: IconMenuRow(icon: icon, label: label),
      );
    }

    return [
      for (final folderPath in mruFolders)
        _buildRecentProjectItem(folderPath, accessible.contains(folderPath)),
      if (mruFolders.isNotEmpty) const PopupMenuDivider(),
      action(
        ProjectMenuAction.openFolder,
        Icons.create_new_folder_outlined,
        'Open Existing Project...',
      ),
      action(
        ProjectMenuAction.createProject,
        Icons.add_box_outlined,
        'Create new Project...',
      ),
      action(
        ProjectMenuAction.closeProject,
        Icons.folder_off_outlined,
        'Close Project',
      ),
    ];
  }

  /// The menu entry switching to [folderPath], shown locked when not
  /// [hasAccess].
  PopupMenuItem<(ProjectMenuAction, String?)> _buildRecentProjectItem(
    String folderPath,
    bool hasAccess,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem(
      value: (ProjectMenuAction.switchProject, folderPath),
      child: IconMenuRow(
        icon: hasAccess ? Icons.folder : Icons.folder_off,
        label: p.basename(folderPath),
        isError: !hasAccess,
        trailing: hasAccess
            ? null
            : Icon(
                Icons.lock,
                color: colorScheme.error,
                size: AppIconSize.small,
              ),
      ),
    );
  }

  /// Shows a positioned popup menu anchored below the project name button.
  void _showProjectMenu(
    BuildContext context,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<(ProjectMenuAction, String?)>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height,
      ),
      items: _buildDropdownMenuItems(
        mruFolders,
        ref.read(accessibleMruFoldersProvider),
      ),
    ).then((choice) async {
      if (choice != null) {
        await _handleDropdownSelection(choice.$1, choice.$2, ref);
      }
    });
  }

  /// Opens the settings dialog for configuring app-level preferences.
  void _showSettingsDialog() {
    showThemeSettingsDialog(
      context,
      (themeMode) => widget.onThemeChanged?.call(themeMode),
    );
  }
}
