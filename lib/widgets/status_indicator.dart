import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';

/// An icon followed by an optional label, both in one color, marking a
/// status such as success, warning or error.
class StatusIndicator extends StatelessWidget {
  /// Creates an indicator drawing [icon], then [label] when given, in
  /// [color].
  const StatusIndicator({
    super.key,
    required this.icon,
    this.label,
    required this.color,
  });

  /// Creates an indicator with the icon and color of [tone].
  StatusIndicator.tone(StatusTone tone, {super.key, this.label})
    : icon = tone.icon,
      color = tone.color;

  /// The color of the icon and text
  final Color color;

  /// The icon to display
  final IconData icon;

  /// The text label to display next to the icon; icon only when null
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.medium,
      children: [
        Icon(
          icon,
          size: AppIconSize.medium,
          color: AppTheme.readable(color, colorScheme),
        ),
        if (text != null)
          Flexible(child: Text(text, style: labelStyle(color, colorScheme))),
      ],
    );
  }

  /// The style of a status label drawn in [color], made readable on the
  /// surfaces of [colorScheme].
  static TextStyle labelStyle(Color color, ColorScheme colorScheme) =>
      AppTextStyle.captionStrong.copyWith(
        color: AppTheme.readable(color, colorScheme),
      );
}
