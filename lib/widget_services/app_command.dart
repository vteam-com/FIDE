import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/widget_services/file_open_actions.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The file and project commands both the native File menu and the title
/// bar's project menu offer, so the two read and act alike.
enum AppCommand {
  quickOpen('Go to File...', Icons.search, AppShortcut.quickOpen),
  openFile('Open File...', Icons.file_open_outlined, AppShortcut.openFile),
  openProject('Open Existing Project...', Icons.create_new_folder_outlined),
  createProject('Create New Project...', Icons.add_box_outlined),
  closeProject('Close Project', Icons.folder_off_outlined);

  /// The commands in their menu groups: opening files, then projects.
  static const List<List<AppCommand>> groups = [
    [quickOpen, openFile],
    [openProject, createProject, closeProject],
  ];

  /// The command, as its menu items read.
  final String label;

  /// The command's icon in the title bar's project menu.
  final IconData icon;

  /// Keys running the command, when it has any.
  final SingleActivator? shortcut;

  const AppCommand(this.label, this.icon, [this.shortcut]);

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

  /// Runs the command; [context] shows the dialogs it opens.
  void run(BuildContext context, WidgetRef ref) {
    final view = ref.read(appViewProvider.notifier);
    switch (this) {
      case AppCommand.quickOpen:
        quickOpenFile(context, ref);
      case AppCommand.openFile:
        pickAndOpenFile(ref);
      case AppCommand.openProject:
        view.pickAndOpenProject();
      case AppCommand.createProject:
        view.showCreateProject();
      case AppCommand.closeProject:
        view.closeProject();
    }
  }
}
