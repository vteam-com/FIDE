import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats modifiers in macOS menu order', () {
    expect(
      ShortcutHelpEntry.format(
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          meta: true,
          shift: true,
          control: true,
          alt: true,
        ),
      ),
      '⌃⌥⇧⌘G',
    );
    expect(ShortcutHelpEntry.format(AppShortcut.openFile), '⇧⌘O');
    expect(
      ShortcutHelpEntry.format(
        const SingleActivator(LogicalKeyboardKey.tab, control: true),
      ),
      '⌃⇥',
    );
  });

  test('lists menu items with shortcuts, groups included, with aliases', () {
    final entries = ShortcutHelpEntry.fromMenus([
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItemGroup(
            members: [
              const PlatformMenuItem(
                label: 'Go to File...',
                shortcut: AppShortcut.quickOpen,
              ),
              const PlatformMenuItem(label: 'Open folder'),
            ],
          ),
        ],
      ),
      const PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItem(
            label: 'Panel Left',
            shortcut: SingleActivator(LogicalKeyboardKey.digit1, meta: true),
          ),
        ],
      ),
    ], aliases: AppShortcut.aliases);

    expect(
      [for (final e in entries) '${e.menu}|${e.label}|${e.keys.join(' ')}'],
      ['File|Go to File|⌘P ⌘O', 'View|Panel Left|⌘1'],
    );
  });
}
