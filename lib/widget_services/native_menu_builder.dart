import 'package:fide/constants/constants.dart';
import 'package:fide/models/hot_reload.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/active_terminal.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/app_quit.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/project_git_actions.dart';
import 'package:fide/widgets/goto_line_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
      _buildRunMenu(),
    ];
  }

  /// Builds the FIDE application menu (About, Settings, Quit).
  PlatformMenu _buildFideMenu() {
    return PlatformMenu(
      label: AppName.short,
      menus: [
        PlatformMenuItem(label: 'About', onSelected: _showAbout),
        PlatformMenuItem(
          label: 'Settings',
          shortcut: AppShortcut.settings,
          onSelected: () => showSettings(ref),
        ),
        const PlatformMenuItem(
          label: 'Quit ${AppName.short}',
          shortcut: AppShortcut.quit,
          onSelected: quitApp,
        ),
      ],
    );
  }

  /// Shows the About dialog, naming FIDE's version.
  Future<void> _showAbout() async {
    final version = await ref.read(appVersionProvider.future);
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: AppName.short,
      applicationVersion: version,
      applicationLegalese: '© 2025 ${AppName.short}',
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

  /// Builds the Edit menu with the find, go-to-line, go-to-definition, go
  /// back and forward, and clear terminal items.
  PlatformMenu _buildEditMenu() {
    final editor = ref.read(activeEditorProvider);
    final documents = ref.read(openDocumentsProvider.notifier);
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
        PlatformMenuItem(
          label: 'Go to Definition',
          shortcut: AppShortcut.goToDefinition,
          onSelected: editor.goToDefinition,
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Go Back',
              shortcut: AppShortcut.goBack,
              onSelected: documents.goBack,
            ),
            PlatformMenuItem(
              label: 'Go Forward',
              shortcut: AppShortcut.goForward,
              onSelected: documents.goForward,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Clear Terminal',
              shortcut: AppShortcut.clearTerminal,
              // Disabled, leaving ⌘K to the other panels, unless the
              // terminal is active
              onSelected: ref.read(terminalActiveProvider)
                  ? ref.read(activeTerminalProvider).clear
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the Run menu: hot reload and hot restart the running apps,
  /// enabled while one runs that hot reloads.
  PlatformMenu _buildRunMenu() {
    final runner = ref.read(commandRunnerProvider.notifier);
    final canReload = ref.read(commandRunnerProvider).canReload;
    return PlatformMenu(
      label: 'Run',
      menus: [
        for (final kind in HotReload.values)
          PlatformMenuItem(
            label: kind.label,
            shortcut: kind.shortcut,
            onSelected: canReload ? () => runner.reloadApps(kind) : null,
          ),
      ],
    );
  }

  /// Builds the View menu with panel show/hide, panel-tab and zoom items.
  PlatformMenu _buildViewMenu() {
    final controller = ref.read(zoomProvider.notifier);
    return PlatformMenu(
      label: 'View',
      menus: [
        for (final panel in SidePanel.values)
          PlatformMenuItem(
            label: panel.commandLabel,
            shortcut: panel.shortcut,
            onSelected: () => togglePanelVisible(ref, panel),
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
            for (final view in CenterView.values)
              PlatformMenuItem(
                label: view.label,
                onSelected: () => showCenterView(ref, view),
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
