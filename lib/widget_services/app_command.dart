import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/widget_services/file_open_actions.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What an [AppCommand] does; [context] shows the dialogs it opens.
typedef AppCommandAction = void Function(BuildContext context, WidgetRef ref);

/// The file and project commands both the native File menu and the title
/// bar's project menu offer, so the two read and act alike.
enum AppCommand {
  quickOpen(
    'Go to File...',
    Icons.search,
    quickOpenFile,
    shortcut: AppShortcut.quickOpen,
  ),
  openFile(
    'Open File...',
    Icons.file_open_outlined,
    _pickAndOpenFile,
    shortcut: AppShortcut.openFile,
  ),
  openProject(
    'Open Existing Project...',
    Icons.create_new_folder_outlined,
    _pickAndOpenProject,
  ),
  createProject(
    'Create New Project...',
    Icons.add_box_outlined,
    _showCreateProject,
  ),
  closeProject('Close Project', Icons.folder_off_outlined, _closeProject);

  /// The commands in their menu groups: opening files, then projects.
  static const List<List<AppCommand>> groups = [
    [quickOpen, openFile],
    [openProject, createProject, closeProject],
  ];

  /// What the command does.
  final AppCommandAction action;

  /// The command, as its menu items read.
  final String label;

  /// The command's icon in the title bar's project menu.
  final IconData icon;

  /// Keys running the command, when it has any.
  final SingleActivator? shortcut;

  const AppCommand(this.label, this.icon, this.action, {this.shortcut});

  /// The command's item in the native menus.
  PlatformMenuItem menuItem(BuildContext context, WidgetRef ref) {
    return PlatformMenuItem(
      label: label,
      shortcut: shortcut,
      onSelected: () => run(context, ref),
    );
  }

  /// The command's item in a popup menu, whose value runs it.
  PopupMenuItem<VoidCallback> popupItem(BuildContext context, WidgetRef ref) {
    return IconMenuItem(
      value: () => run(context, ref),
      icon: icon,
      label: label,
    );
  }

  /// Runs the command's [action]; [context] shows the dialogs it opens.
  void run(BuildContext context, WidgetRef ref) => action(context, ref);
}

/// Closes the open project.
void _closeProject(BuildContext _, WidgetRef ref) =>
    ref.read(appViewProvider.notifier).closeProject();

/// Lets the user pick a file to open in the editor.
void _pickAndOpenFile(BuildContext _, WidgetRef ref) => pickAndOpenFile(ref);

/// Lets the user pick a project folder to open.
void _pickAndOpenProject(BuildContext _, WidgetRef ref) =>
    ref.read(appViewProvider.notifier).pickAndOpenProject();

/// Shows the new-project wizard.
void _showCreateProject(BuildContext _, WidgetRef ref) =>
    ref.read(appViewProvider.notifier).showCreateProject();
