import 'package:fide/constants/constants.dart';
import 'package:fide/controllers/app_controller.dart';
import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `NativeMenuBuilder`.
class NativeMenuBuilder {
  final BuildContext context;
  final WidgetRef ref;
  final Function() onOpenFolder;

  /// Go to File: the palette over the project's files.
  final VoidCallback onQuickOpen;

  /// Open File: the platform's file dialog.
  final VoidCallback onOpenFile;
  final Function() onSave;
  final Function() onCloseDocument;
  final Function() onFind;
  final Function() onFindNext;
  final Function() onFindPrevious;
  final Function() onGoToLine;
  final ValueChanged<LeftPanelTab> onSwitchPanel;
  final Function(String) onProjectSwitch;
  final Function()? onCloseProject;
  final String? lastOpenedFileName;

  /// Shows the settings screen.
  final VoidCallback onShowSettings;

  NativeMenuBuilder({
    required this.context,
    required this.ref,
    required this.onOpenFolder,
    required this.onQuickOpen,
    required this.onOpenFile,
    required this.onSave,
    required this.onCloseDocument,
    required this.onFind,
    required this.onFindNext,
    required this.onFindPrevious,
    required this.onGoToLine,
    required this.onSwitchPanel,
    required this.onProjectSwitch,
    this.onCloseProject,
    this.lastOpenedFileName,
    required this.onShowSettings,
  });

  /// Builds the native platform menu structure for the app shell.
  List<PlatformMenu> buildMenus() {
    return [
      _buildFideMenu(),
      _buildFileMenu(),
      _buildEditMenu(),
      _buildViewMenu(),
    ];
  }

  /// Builds the FIDE application menu (About, Hide, Quit, etc.).
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
          shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
          onSelected: onShowSettings,
        ),
        PlatformMenuItem(
          label: 'Quit FIDE',
          shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
          onSelected: () {
            SystemNavigator.pop();
          },
        ),
      ],
    );
  }

  /// Builds the File menu with open-file, open-folder, save, and
  /// close-project items.
  PlatformMenu _buildFileMenu() {
    return PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Go to File...',
              shortcut: AppShortcut.quickOpen,
              onSelected: onQuickOpen,
            ),
            PlatformMenuItem(
              label: 'Open File...',
              shortcut: AppShortcut.openFile,
              onSelected: onOpenFile,
            ),
          ],
        ),
        PlatformMenuItem(
          label: 'Open folder',
          onSelected: () async {
            onOpenFolder();
          },
        ),
        if (onCloseProject != null)
          PlatformMenuItem(
            label: 'Close Project',
            onSelected: () {
              onCloseProject!();
            },
          ),
        PlatformMenuItem(
          label: _getLastOpenedFileLabel(),
          onSelected: () {
            // This would be handled by the parent - reopen last file
          },
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Initialize Repository',
              onSelected: () async {
                final currentPath = ref.read(currentProjectPathProvider);
                if (currentPath != null) {
                  final gitService = ref.read(gitServiceProvider);
                  try {
                    final result = await gitService.initRepository(currentPath);
                    if (context.mounted) {
                      MessageBox.showSuccess(context, result);
                    }
                  } on GitException catch (e) {
                    if (context.mounted) {
                      MessageBox.showError(context, '$e');
                    }
                  }
                }
              },
            ),
            PlatformMenuItem(
              label: 'Refresh Status',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                // This will be handled by the Git panel refresh
              },
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Save',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
              onSelected: () {
                onSave();
              },
            ),
            PlatformMenuItem(
              label: 'Close Document',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: true,
              ),
              onSelected: () {
                onCloseDocument();
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the Edit menu with find, find-previous, and go-to-line items.
  PlatformMenu _buildEditMenu() {
    return PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(
          label: 'Find',
          shortcut: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
          onSelected: () {
            onFind();
          },
        ),
        PlatformMenuItem(
          label: 'Find Next',
          shortcut: const SingleActivator(LogicalKeyboardKey.keyG, meta: true),
          onSelected: () {
            onFindNext();
          },
        ),
        PlatformMenuItem(
          label: 'Find Previous',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyG,
            meta: true,
            shift: true,
          ),
          onSelected: () {
            onFindPrevious();
          },
        ),
        PlatformMenuItem(
          label: 'Go to Line',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyG,
            control: true,
          ),
          onSelected: () {
            onGoToLine();
          },
        ),
      ],
    );
  }

  /// Builds the View menu with panel-visibility, layout toggle and zoom
  /// items.
  PlatformMenu _buildViewMenu() {
    return PlatformMenu(
      label: 'View',
      menus: [
        for (final (label, digit, visible, expanded) in [
          (
            'Panel Left',
            LogicalKeyboardKey.digit1,
            leftPanelVisibleProvider,
            leftPanelExpandedProvider,
          ),
          (
            'Panel Bottom',
            LogicalKeyboardKey.digit2,
            bottomPanelVisibleProvider,
            bottomPanelExpandedProvider,
          ),
          (
            'Panel Right',
            LogicalKeyboardKey.digit3,
            rightPanelVisibleProvider,
            rightPanelExpandedProvider,
          ),
        ])
          PlatformMenuItem(
            label: '$label: Hide, Min, Max',
            shortcut: SingleActivator(digit, meta: true),
            onSelected: () => cyclePanelSize(ref, visible, expanded),
          ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Next Left Panel Tab',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.digit1,
                control: true,
              ),
              onSelected: () => nextLeftPanelTab(ref),
            ),
            PlatformMenuItem(
              label: 'Next Right Panel Tab',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.digit3,
                control: true,
              ),
              onSelected: () => nextRightPanelTab(ref),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Zoom In',
              shortcut: AppShortcut.zoomIn,
              onSelected: ref.read(appControllerProvider).zoomIn,
            ),
            PlatformMenuItem(
              label: 'Zoom Out',
              shortcut: AppShortcut.zoomOut,
              onSelected: ref.read(appControllerProvider).zoomOut,
            ),
            PlatformMenuItem(
              label: 'Actual Size',
              shortcut: AppShortcut.actualSize,
              onSelected: ref.read(appControllerProvider).resetZoom,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: 'Explorer',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyE,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(LeftPanelTab.folder);
              },
            ),
            PlatformMenuItem(
              label: 'Organized',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyJ,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(LeftPanelTab.organized);
              },
            ),
            PlatformMenuItem(
              label: 'Git',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyG,
                control: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(LeftPanelTab.git);
              },
            ),
            PlatformMenuItem(
              label: 'Search',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyF,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(LeftPanelTab.search);
              },
            ),
          ],
        ),
      ],
    );
  }

  String _getLastOpenedFileLabel() {
    if (lastOpenedFileName != null) {
      return 'Last file opened: $lastOpenedFileName';
    }
    return 'No file opened';
  }
}
