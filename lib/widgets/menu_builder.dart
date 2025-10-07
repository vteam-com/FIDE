import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../providers/app_providers.dart';

// Services
import '../services/git_service.dart';

// Utils
import '../utils/message_box.dart';

class MenuBuilder {
  final BuildContext context;
  final WidgetRef ref;
  final Function() onOpenFolder;
  final Function() onSave;
  final Function() onCloseDocument;
  final Function() onFind;
  final Function() onFindNext;
  final Function() onFindPrevious;
  final Function() onGoToLine;
  final Function() onToggleLeftPanel;
  final Function() onToggleBottomPanel;
  final Function() onToggleRightPanel;
  final Function(int) onSwitchPanel;
  final Function(String) onProjectSwitch;
  final Function()? onCloseProject;
  final String? lastOpenedFileName;
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  MenuBuilder({
    required this.context,
    required this.ref,
    required this.onOpenFolder,
    required this.onSave,
    required this.onCloseDocument,
    required this.onFind,
    required this.onFindNext,
    required this.onFindPrevious,
    required this.onGoToLine,
    required this.onToggleLeftPanel,
    required this.onToggleBottomPanel,
    required this.onToggleRightPanel,
    required this.onSwitchPanel,
    required this.onProjectSwitch,
    this.onCloseProject,
    this.lastOpenedFileName,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  List<PlatformMenu> buildMenus() {
    return [
      _buildFideMenu(),
      _buildFileMenu(),
      _buildEditMenu(),
      _buildViewMenu(),
    ];
  }

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
          onSelected: () => _showSettingsDialog(),
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

  PlatformMenu _buildFileMenu() {
    return PlatformMenu(
      label: 'File',
      menus: [
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
                  final gitService = GitService();
                  final result = await gitService.initRepository(currentPath);
                  if (context.mounted) {
                    MessageBox.showInfo(context, result);
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

  PlatformMenu _buildViewMenu() {
    return PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Panel Left',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit1,
            meta: true,
          ),
          onSelected: () {
            onToggleLeftPanel();
          },
        ),
        PlatformMenuItem(
          label: 'Panel Bottom',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit2,
            meta: true,
          ),
          onSelected: () {
            onToggleBottomPanel();
          },
        ),
        PlatformMenuItem(
          label: 'Panel Right',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.digit3,
            meta: true,
          ),
          onSelected: () {
            onToggleRightPanel();
          },
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
                onSwitchPanel(0);
              },
            ),
            PlatformMenuItem(
              label: 'Organized',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(1);
              },
            ),
            PlatformMenuItem(
              label: 'Git',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyG,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                onSwitchPanel(2);
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
                onSwitchPanel(3);
              },
            ),
          ],
        ),
      ],
    );
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
                onTap: () {
                  onThemeChanged(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () {
                  onThemeChanged(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () {
                  onThemeChanged(ThemeMode.dark);
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

  String _getLastOpenedFileLabel() {
    if (lastOpenedFileName != null) {
      return 'Last file opened: $lastOpenedFileName';
    }
    return 'No file opened';
  }
}
