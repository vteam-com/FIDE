import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A centered message for a panel or screen that has nothing to show, or
/// can't show what was asked: an optional [icon] and [title], the
/// [message], then an optional [child] such as a retry button.
class EmptyState extends StatelessWidget {
  /// Creates the placeholder for [message].
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.child,
    this.isError = false,
  });

  /// Content under [message], such as an action or a link.
  final Widget? child;

  /// Large glyph shown first; none when null.
  final IconData? icon;

  /// Whether the state is a failure, drawing [icon] and [title] in the
  /// error color.
  final bool isError;

  /// Why the panel is empty, or what to do to fill it.
  final String message;

  /// Headline above [message]; none when null.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = isError ? theme.colorScheme.error : muted;
    final title = this.title;
    final child = this.child;
    return Center(
      child: SingleChildScrollView(
        padding: AppPadding.panelContent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xLarge,
          children: [
            if (icon != null)
              Icon(icon, size: AppIconSize.emptyState, color: accent),
            if (title != null)
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: accent),
              ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppFontSize.label, color: muted),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}
