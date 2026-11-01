import 'package:flutter/widgets.dart';

/// One command of the keyboard shortcut help: the menu it is in, its
/// label and the keys that run it.
class ShortcutHelpEntry {
  /// Creates the entry for the [label] command of [menu], run by [keys].
  const ShortcutHelpEntry({
    required this.menu,
    required this.label,
    required this.keys,
  });

  /// Modifier symbols in the order macOS menus show them.
  static const String _control = '⌃';
  static const String _alt = '⌥';
  static const String _shift = '⇧';
  static const String _meta = '⌘';

  /// Ellipsis ending labels of commands that ask for more input.
  static const String _ellipsis = '...';

  /// The keys that run the command, each as macOS menus show it, such as
  /// `⇧⌘O`; the menu's own shortcut first.
  final List<String> keys;

  /// The command, as its menu item reads.
  final String label;

  /// The top-level menu holding the command, such as File.
  final String menu;

  /// The commands of [menus] that have a keyboard shortcut, in menu order.
  /// [aliases] adds a second key to the item whose shortcut is its key.
  static List<ShortcutHelpEntry> fromMenus(
    List<PlatformMenuItem> menus, {
    Map<SingleActivator, SingleActivator> aliases = const {},
  }) {
    final entries = <ShortcutHelpEntry>[];
    void collect(String menu, Iterable<PlatformMenuItem> items) {
      for (final item in items) {
        switch (item) {
          case PlatformMenu(:final menus):
            collect(menu, menus);
          case PlatformMenuItemGroup(:final members):
            collect(menu, members);
          case PlatformMenuItem(:final SingleActivator shortcut):
            entries.add(
              ShortcutHelpEntry(
                menu: menu,
                label: item.label.replaceAll(_ellipsis, ''),
                keys: [
                  format(shortcut),
                  if (aliases[shortcut] case final alias?) format(alias),
                ],
              ),
            );
          default:
        }
      }
    }

    for (final menu in menus) {
      if (menu is PlatformMenu) collect(menu.label, menu.menus);
    }
    return entries;
  }

  /// The tooltip of a button running [label], followed by its [shortcut]
  /// when it has one, such as `Settings (⌘,)`.
  static String tooltip(String label, [SingleActivator? shortcut]) {
    return shortcut == null ? label : '$label (${format(shortcut)})';
  }

  /// [activator] as macOS menus show it, such as `⇧⌘O`.
  static String format(SingleActivator activator) {
    return [
      if (activator.control) _control,
      if (activator.alt) _alt,
      if (activator.shift) _shift,
      if (activator.meta) _meta,
      activator.trigger.keyLabel.toUpperCase(),
    ].join();
  }
}
