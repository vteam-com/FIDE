// ignore_for_file:  use_build_context_synchronously

import 'dart:io';
import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_view_state.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widgets/app_menu_bar.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/dropdown_label.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/project_icon.dart';
import 'package:fide/widgets/window_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

// Widgets

/// The window's title bar: the project menu, the app menus where the
/// platform has no native menu bar, the side panel buttons while a project
/// is open, the settings button, and the window buttons on Linux.
class AppTitleBar extends ConsumerStatefulWidget {
  /// Creates the title bar showing [menus] off macOS.
  const AppTitleBar({super.key, required this.menus});

  /// The app menus; macOS shows them natively, other platforms in this bar.
  final List<PlatformMenuItem> menus;

  @override
  ConsumerState<AppTitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends ConsumerState<AppTitleBar> {
  @override
  Widget build(BuildContext context) {
    // The native window buttons do not zoom: keep their space on screen and
    // the bar no shorter than they need
    final zoom = ref.watch(zoomProvider);
    return SizedBox(
      height: AppSize.titleBarHeight / min(zoom, AppZoom.actualSize),
      child: Row(
        children: [
          // Drags the window, runs the platform's title-bar double-click
          // action and opens the system window menu on a secondary click.
          Expanded(child: DragToMoveArea(child: _buildBar())),
          // The hidden title bar drops Linux's native window buttons
          if (Platform.isLinux) const WindowButtons(),
        ],
      ),
    );
  }

  /// The bar's content, dragging the window from its empty space.
  Widget _buildBar() {
    final zoom = ref.watch(zoomProvider);
    return Container(
      // Transparent so the window's workspace gradient runs behind it
      color: Colors.transparent,
      child: Row(
        children: [
          // Platform-specific spacing for window controls
          if (Platform.isMacOS)
            SizedBox(
              width: AppSize.macWindowControlsSpacing / zoom,
            ), // Space for macOS traffic lights (left side)
          // Left section: Project dropdown or app title
          Consumer(
            builder: (_, ref, _) {
              final currentProjectPath = ref.watch(currentProjectPathProvider);
              final mruFolders = ref.watch(mruFoldersProvider);
              // Look up the recent projects' icons ahead of the menu.
              for (final folder in ref.watch(accessibleMruFoldersProvider)) {
                ref.read(projectIconPathProvider(folder));
              }

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

          // macOS shows these menus natively
          if (!Platform.isMacOS) AppMenuBar(menus: widget.menus),

          // Center section: Panel toggle buttons (only shown when in main layout)
          if (ref.watch(appViewProvider) == AppViewState.mainLayout)
            Expanded(child: Center(child: _buildPanelToggleButtons()))
          else
            const Spacer(),

          // Right section: Settings button
          _buildSettingsButton(),

          // Spacer to push content away from right-side window controls (Windows/Linux)
          if (!Platform.isMacOS) const Spacer(),

          // Space for the native window controls on Windows (right side)
          if (Platform.isWindows)
            const SizedBox(width: AppSize.desktopWindowControlsSpacing),
        ],
      ),
    );
  }

  /// Builds the project name dropdown button that shows the active project and MRU list.
  Widget _buildProjectDropdown(
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    return Clickable(
      onTap: () => _showProjectMenu(context, mruFolders, ref),
      child: DropdownLabel(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.medium,
          children: [
            ProjectIcon(projectPath: currentProjectPath),
            Flexible(
              child: Text(
                p.basename(currentProjectPath),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AppTextStyle.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the centred app title text widget.
  Widget _buildAppTitle() {
    return Text('The Flutter IDE', style: AppTextStyle.label);
  }

  /// The buttons cycling each [SidePanel] through Hide, Min and Max, each
  /// highlighted while its panel shows.
  Widget _buildPanelToggleButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final panel in SidePanel.values)
          CompactIconButton.svg(
            key: panel.toggleKey,
            svgAsset: panel.asset,
            selected: ref.watch(panel.visibleProvider),
            onPressed: () => cyclePanelSize(ref, panel),
            tooltip: panel.tooltip,
          ),
      ],
    );
  }

  /// Builds the settings gear icon button in the title bar.
  Widget _buildSettingsButton() {
    return CompactIconButton(
      icon: Icons.settings,
      onPressed: () => ref
          .read(settingsVisibleProvider.notifier)
          .update((visible) => !visible),
      tooltip: ShortcutHelpEntry.tooltip('Settings', AppShortcut.settings),
    );
  }

  /// The project menu: recent projects ([accessible] ones openable), then
  /// the [AppCommand] groups; each entry's value runs it.
  List<PopupMenuEntry<VoidCallback>> _buildDropdownMenuItems(
    List<String> mruFolders,
    Set<String> accessible,
  ) {
    return [
      for (final folderPath in mruFolders)
        _buildRecentProjectItem(folderPath, accessible.contains(folderPath)),
      for (final group in AppCommand.groups) ...[
        if (mruFolders.isNotEmpty || group != AppCommand.groups.first)
          const PopupMenuDivider(),
        for (final command in group) command.popupItem(context, ref),
      ],
    ];
  }

  /// The menu entry switching to [folderPath], shown locked when not
  /// [hasAccess].
  PopupMenuItem<VoidCallback> _buildRecentProjectItem(
    String folderPath,
    bool hasAccess,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconMenuItem(
      value: () => ref.read(appViewProvider.notifier).loadProject(folderPath),
      icon: Icons.folder_off,
      leading: hasAccess ? ProjectIcon(projectPath: folderPath) : null,
      label: p.basename(folderPath),
      isError: !hasAccess,
      trailing: hasAccess
          ? null
          : Icon(Icons.lock, color: colorScheme.error, size: AppIconSize.small),
    );
  }

  /// Shows a positioned popup menu anchored below the project name button.
  void _showProjectMenu(
    BuildContext context,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    final button = context.findRenderObject() as RenderBox;
    showActionMenu(
      context,
      button.localToGlobal(button.size.bottomLeft(Offset.zero)),
      _buildDropdownMenuItems(
        mruFolders,
        ref.read(accessibleMruFoldersProvider),
      ),
    );
  }
}
