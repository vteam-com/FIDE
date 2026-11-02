import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A strip above a panel's content, such as its tabs, toolbar or search
/// bar, or below it as a footer, separated from it by a thin divider.
class HeaderBar extends StatelessWidget {
  /// Creates the strip around [child].
  const HeaderBar({super.key, required this.child, this.isFooter = false});

  /// The header content.
  final Widget child;

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
      child: child,
    );
  }
}
