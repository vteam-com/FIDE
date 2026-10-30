import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A strip above a panel's content, such as its tabs, toolbar or search
/// bar, separated from it by a thin divider.
class HeaderBar extends StatelessWidget {
  /// Creates the strip around [child].
  const HeaderBar({super.key, required this.child});

  /// The header content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppSize.borderThin,
          ),
        ),
      ),
      child: child,
    );
  }
}
