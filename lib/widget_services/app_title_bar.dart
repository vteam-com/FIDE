// ignore_for_file:  use_build_context_synchronously

import 'dart:io';
import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_view_state.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widget_services/update_button.dart';
import 'package:fide/widgets/app_menu_bar.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/dropdown_label.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/window_buttons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

// Widgets

/// The window's title bar: the project menu, the app menus where the
/// platform has no native menu bar, the side panel buttons while a project
/// is open, a light bulb while the project's quality needs attention, the
/// update button while a newer FIDE is out, the settings button, and the
/// window buttons on Linux. While the settings screen shows, it holds only
/// the button closing it.
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
    final settingsVisible = ref.watch(settingsVisibleProvider);
    final showsWorkspace =
        !settingsVisible &&
        ref.watch(appViewProvider) == AppViewState.mainLayout;
    final quality = showsWorkspace ? ref.watch(projectQualityProvider) : null;
    return Container(
      // Transparent so the window's workspace gradient runs behind it
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      // The two sides share the width left by the panel buttons equally,
      // so those buttons sit at the bar's center whatever the sides hold
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // Space for the macOS traffic lights
                if (Platform.isMacOS)
                  SizedBox(width: AppSize.macWindowControlsSpacing / zoom),
                if (!settingsVisible) ...[
                  Flexible(child: _buildProjectTitle()),
                  // macOS shows these menus natively
                  if (!Platform.isMacOS) AppMenuBar(menus: widget.menus),
                ],
              ],
            ),
          ),
          if (showsWorkspace) _buildPanelToggleButtons(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Centered between the panel buttons and the settings one
                if (quality != null && quality.needsAttention)
                  Expanded(child: Center(child: _buildQualityButton(quality))),
                if (!settingsVisible) const UpdateButton(),
                settingsVisible
                    ? _buildCloseSettingsButton()
                    : _buildSettingsButton(),
                // Space for the native window controls on Windows
                if (Platform.isWindows)
                  const SizedBox(width: AppSize.desktopWindowControlsSpacing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The project dropdown, or the app title while no project is open.
  Widget _buildProjectTitle() {
    return Consumer(
      builder: (_, ref, _) {
        final currentProjectPath = ref.watch(currentProjectPathProvider);
        final mruFolders = ref.watch(mruFoldersProvider);
        // Look up the recent projects' icons ahead of the menu.
        for (final folder in ref.watch(accessibleMruFoldersProvider)) {
          ref.read(projectIconPathProvider(folder));
        }
        return currentProjectPath == null
            ? _buildAppTitle()
            : _buildProjectDropdown(currentProjectPath, mruFolders, ref);
      },
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

  /// The light bulb telling the project's [quality] needs attention, its
  /// score and most pressing issue as tooltip, showing the overview and
  /// the Info tab when pressed.
  Widget _buildQualityButton(ProjectQuality quality) {
    return CompactIconButton(
      key: const Key('keyQualityBulb'),
      icon: Icons.lightbulb,
      color: StatusTone.warning.readableIn(Theme.of(context).colorScheme),
      tooltip: quality.summary,
      onPressed: () => showProjectQuality(ref),
    );
  }

  /// The buttons cycling each [SidePanel] through Hide, Min and Max, each
  /// highlighted while its panel shows.
  Widget _buildPanelToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.medium,
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
      ),
    );
  }

  /// Builds the settings gear icon button in the title bar.
  Widget _buildSettingsButton() {
    return CompactIconButton(
      icon: Icons.settings,
      onPressed: () => ref.read(settingsVisibleProvider.notifier).state = true,
      tooltip: ShortcutHelpEntry.tooltip('Settings', AppShortcut.settings),
    );
  }

  /// The button leaving the settings screen, as Escape does.
  Widget _buildCloseSettingsButton() {
    return CompactIconButton(
      icon: Icons.close,
      onPressed: () => ref.read(settingsVisibleProvider.notifier).state = false,
      tooltip: 'Close (Esc)',
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
          : Icon(
              Icons.lock,
              color: StatusTone.error.readableIn(colorScheme),
              size: AppIconSize.small,
            ),
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
