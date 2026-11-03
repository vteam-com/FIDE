import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The app's menus drawn by Flutter, for platforms without a native menu bar
/// (Linux, Windows); built from the same [menus] macOS shows natively.
class AppMenuBar extends StatelessWidget {
  /// Creates the bar showing each top-level [PlatformMenu] of [menus].
  const AppMenuBar({super.key, required this.menus});

  /// The native menu structure, as `PlatformMenuBar` takes it.
  final List<PlatformMenuItem> menus;

  @override
  Widget build(BuildContext context) {
    return MenuBar(
      style: const MenuStyle(
        // Blends into the title bar, which paints the workspace behind it
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      children: _buildItems(menus),
    );
  }

  /// The Flutter menu widgets of [items], each [PlatformMenuItemGroup] set
  /// apart from its neighbors by a divider.
  static List<Widget> _buildItems(List<PlatformMenuItem> items) {
    final widgets = <Widget>[];
    void addDivider() {
      if (widgets.isNotEmpty && widgets.last is! Divider) {
        widgets.add(const Divider(height: AppSpacing.medium));
      }
    }

    for (final item in items) {
      switch (item) {
        case PlatformMenu(:final label, :final menus):
          widgets.add(
            SubmenuButton(
              menuChildren: _buildItems(menus),
              child: Text(label, style: AppTextStyle.label),
            ),
          );
        case PlatformMenuItemGroup(:final members):
          addDivider();
          widgets.addAll(_buildItems(members));
          addDivider();
        default:
          widgets.add(
            MenuItemButton(
              shortcut: item.shortcut,
              onPressed: item.onSelected,
              child: Text(item.label, style: AppTextStyle.label),
            ),
          );
      }
    }
    if (widgets.isNotEmpty && widgets.last is Divider) widgets.removeLast();
    return widgets;
  }
}
