import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:flutter/material.dart';

/// A fixed-width outlined card headed by [icon] and [title], showing one
/// headline [value] over a few [details] lines.
class StatCard extends StatelessWidget {
  /// Creates the card.
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.details = const [],
  });

  /// Smaller lines explaining [value].
  final List<String> details;

  /// Shown before [title].
  final IconData icon;

  /// What the card measures.
  final String title;

  /// The headline figure; see [StatCard.text] for plain text.
  final Widget value;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: AppSize.statCardWidth,
      child: OutlinedSurface(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
          children: [
            Row(
              spacing: AppSpacing.medium,
              children: [
                Icon(icon, size: AppIconSize.large, color: colorScheme.primary),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppFontSize.label,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            value,
            for (final detail in details)
              Text(
                detail,
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// [value] as headline text.
  static Widget text(BuildContext context, String value) =>
      Text(value, style: Theme.of(context).textTheme.headlineMedium);
}
