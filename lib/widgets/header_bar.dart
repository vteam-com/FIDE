import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A strip above a panel's content, such as its tabs, toolbar or search
/// bar, or below it as a footer, separated from it by a thin divider.
class HeaderBar extends StatelessWidget {
  /// Creates the strip around [child], inset by the panels' content
  /// padding.
  const HeaderBar({super.key, required this.child, this.isFooter = false})
    : height = null;

  /// Creates the strip atop a panel around [child], as tall as every
  /// panel's, so the side panels' tabs and the editor header line up.
  const HeaderBar.top({super.key, required this.child})
    : isFooter = false,
      height = AppSize.panelHeaderHeight;

  /// The header content.
  final Widget child;

  /// The strip's fixed height, or null to fit [child].
  final double? height;

  /// Whether the strip sits below the content, its divider on top.
  final bool isFooter;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: Theme.of(context).dividerColor,
      width: AppSize.borderThin,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isFooter ? Border(top: divider) : Border(bottom: divider),
      ),
      child: height == null
          ? Padding(padding: AppPadding.panelContent, child: child)
          : SizedBox(height: height, child: child),
    );
  }
}
