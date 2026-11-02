import 'package:fide/constants/constants.dart';
import 'package:fide/controllers/app_controller.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/project_git_actions.dart';
import 'package:fide/widgets/goto_line_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the app's native menus; every item runs its command through
/// [ref], showing any dialog over [context].
class NativeMenuBuilder {
  /// Context under the app's navigator, for the dialogs menu items open.
  final BuildContext context;

  /// Reaches the state and commands the menu items act on.
  final WidgetRef ref;

  /// Creates the builder of the menus acting through [ref] and [context].
  NativeMenuBuilder({required this.context, required this.ref});

  /// Builds the native platform menu structure for the app shell.
  List<PlatformMenu> buildMenus() {
    return [
      _buildFideMenu(),
      _buildFileMenu(),
      _buildEditMenu(),
      _buildViewMenu(),
    ];
  }

  /// Builds the FIDE application menu (About, Settings, Quit).
  PlatformMenu _buildFideMenu() {
    return PlatformMenu(
      label: 'FIDE',
      menus: [
        PlatformMenuItem(
          label: 'About',
          onSelected: () {
            showAboutDialog(
              context: context,
              applicationName: 'FIDE',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 FIDE',
            );
          },
        ),
        PlatformMenuItem(
          label: 'Settings',
          shortcut: AppShortcut.settings,
          onSelected: () =>
              ref.read(settingsVisibleProvider.notifier).state = true,
        ),
        const PlatformMenuItem(
          label: 'Quit FIDE',
          shortcut: AppShortcut.quit,
          onSelected: SystemNavigator.pop,
        ),
      ],
    );
  }

  /// Builds the File menu: the [AppCommand]s, the Git items, then save and
  /// close.
  PlatformMenu _buildFileMenu() {
    final editor = ref.read(activeEditorProvider);
    return PlatformMenu(
      label: 'File',
      menus: [
        for (final group in AppCommand.groups)
          PlatformMenuItemGroup(
            members: [
              for (final command in group) command.menuItem(context, ref),
            ],
          ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Initialize Repository',
              onSelected: () => initProjectRepository(context, ref),
            ),
            PlatformMenuItem(
              label: 'Refresh Status',
              shortcut: AppShortcut.refreshGitStatus,
              onSelected: () => refreshProjectGitStatus(ref),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Save',
              shortcut: AppShortcut.save,
              onSelected: editor.save,
            ),
            PlatformMenuItem(
              label: 'Close Document',
              shortcut: AppShortcut.closeDocument,
              onSelected: editor.close,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the Edit menu with find, find-previous, and go-to-line items.
  PlatformMenu _buildEditMenu() {
    final editor = ref.read(activeEditorProvider);
    return PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(
          label: 'Find',
          shortcut: AppShortcut.find,
          onSelected: editor.openSearch,
        ),
        PlatformMenuItem(
          label: 'Find Next',
          shortcut: AppShortcut.findNext,
          onSelected: editor.findNext,
        ),
        PlatformMenuItem(
          label: 'Find Previous',
          shortcut: AppShortcut.findPrevious,
          onSelected: editor.findPrevious,
        ),
        PlatformMenuItem(
          label: 'Go to Line',
          shortcut: AppShortcut.goToLine,
          onSelected: () => GotoLineDialog.show(context, editor),
        ),
      ],
    );
  }

  /// Builds the View menu with panel-size, panel-tab and zoom items.
  PlatformMenu _buildViewMenu() {
    final controller = ref.read(appControllerProvider);
    return PlatformMenu(
      label: 'View',
      menus: [
        for (final panel in SidePanel.values)
          PlatformMenuItem(
            label: panel.commandLabel,
            shortcut: panel.shortcut,
            onSelected: () => cyclePanelSize(ref, panel),
          ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Next Left Panel Tab',
              shortcut: AppShortcut.nextLeftPanelTab,
              onSelected: () => nextLeftPanelTab(ref),
            ),
            PlatformMenuItem(
              label: 'Next Right Panel Tab',
              shortcut: AppShortcut.nextRightPanelTab,
              onSelected: () => nextRightPanelTab(ref),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'App Icons',
              onSelected: () => showAppIcons(ref),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Zoom In',
              shortcut: AppShortcut.zoomIn,
              onSelected: controller.zoomIn,
            ),
            PlatformMenuItem(
              label: 'Zoom Out',
              shortcut: AppShortcut.zoomOut,
              onSelected: controller.zoomOut,
            ),
            PlatformMenuItem(
              label: 'Actual Size',
              shortcut: AppShortcut.actualSize,
              onSelected: controller.resetZoom,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            for (final tab in LeftPanelTab.values)
              if (tab.shortcut case final shortcut?)
                PlatformMenuItem(
                  label: tab.label,
                  shortcut: shortcut,
                  onSelected: () => switchLeftPanelTab(ref, tab),
                ),
          ],
        ),
      ],
    );
  }
}
