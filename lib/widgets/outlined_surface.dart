import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A rounded box on the surface color with a thin outline, grouping related
/// controls or a notice inside a panel.
class OutlinedSurface extends StatelessWidget {
  /// Creates the box around [child], inset by [padding].
  const OutlinedSurface({
    super.key,
    required this.padding,
    required this.child,
    this.borderColor,
  });

  /// Outline color; the theme's faint outline when null.
  final Color? borderColor;

  /// The content.
  final Widget child;

  /// Space between the outline and [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color:
              borderColor ??
              colorScheme.outline.withValues(alpha: AppOpacity.divider),
          width: AppSize.borderThin,
        ),
      ),
      child: child,
    );
  }
}
