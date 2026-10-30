import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:flutter/material.dart';

/// An outlined card offering one task: a [title], what it does, the steps
/// it takes and the button that starts it.
class ActionCard extends StatelessWidget {
  /// Creates a card titled [title].
  const ActionCard({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.steps = const [],
    this.child,
    this.action,
  });

  /// Button that starts the task, aligned to the end of the card.
  final Widget? action;

  /// Extra content shown under the steps, such as the current state.
  final Widget? child;

  /// What the task does.
  final String? description;

  /// Glyph shown before [title], in the primary color.
  final IconData? icon;

  /// What the task will do, one line each.
  final List<String> steps;

  /// The task's name.
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;
    final child = this.child;
    final action = this.action;
    return OutlinedSurface(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.medium,
        children: [
          Row(
            spacing: AppSpacing.medium,
            children: [
              if (icon != null) Icon(icon, color: theme.colorScheme.primary),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (description != null)
            Text(description, style: theme.textTheme.bodyMedium),
          for (final step in steps)
            Text(
              '• $step',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ?child,
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
