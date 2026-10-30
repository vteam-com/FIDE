import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// A list entry in an outlined box: [icon], [title] over [subtitle], an
/// optional [trailing] widget, and a tap action; disabled when [onTap] is
/// null.
class OutlinedListTile extends StatelessWidget {
  /// Creates the entry for [title].
  const OutlinedListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  /// Leading glyph.
  final IconData icon;

  /// Color of [icon]; the primary color when null.
  final Color? iconColor;

  /// Called when the entry is tapped; the entry is disabled when null.
  final VoidCallback? onTap;

  /// Second line, such as a path or description.
  final String subtitle;

  /// The entry's name.
  final String title;

  /// Widgets after the text, such as a status or a button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: OutlinedSurface(
        padding: SurfacePadding.none,
        // Transparent Material so the ListTile's ink effects paint above
        // the surface's background color.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            enabled: onTap != null,
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xLarge,
              vertical: AppSpacing.tiny,
            ),
            leading: Icon(
              icon,
              color: iconColor ?? theme.colorScheme.primary,
              size: AppIconSize.large,
            ),
            title: Text(
              title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              subtitle,
              style: AppTheme.secondaryText(context),
              maxLines: AppMetric.doubleLineLimit,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
