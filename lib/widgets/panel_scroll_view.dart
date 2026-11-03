import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A side panel's scrolling content: [children] stacked full width, one
/// section gap apart, inset by the panels' content padding (inside the
/// scroll view, so content scrolls to the panel's edges).
class PanelScrollView extends StatelessWidget {
  /// Creates the scrolling stack of [children].
  const PanelScrollView({super.key, required this.children});

  /// The panel's sections, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppPadding.panelContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sectionGap,
        children: children,
      ),
    );
  }
}
