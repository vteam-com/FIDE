import 'package:fide/constants/constants.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A full screen (welcome, create project, loading): the screen gradient
/// behind [child], inset by the screen padding.
class ScreenScaffold extends StatelessWidget {
  /// Creates the screen around [child].
  const ScreenScaffold({super.key, required this.child});

  /// The screen's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.screenBackground(context),
      child: Padding(padding: AppPadding.screen, child: child),
    );
  }
}
