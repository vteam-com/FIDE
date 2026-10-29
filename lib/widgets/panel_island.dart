import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A rounded, softly outlined surface that floats a workspace panel above
/// the `AppTheme.workspaceBackground` gradient.
class PanelIsland extends StatelessWidget {
  /// Creates an island around [child].
  const PanelIsland({super.key, required this.child});
  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(AppRadius.island),
  );

  /// The panel content, clipped to the island's rounded corners.
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      // Drawn over the content so scrolled children never hide the edge
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: AppOpacity.muted),
          width: AppSize.borderThin,
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: ColoredBox(color: colorScheme.surface, child: child),
      ),
    );
  }
}
