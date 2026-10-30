import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/status_tone.dart';
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.medium,
      children: [
        Icon(icon, size: AppIconSize.medium, color: color),
        if (text != null)
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppFontSize.caption,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// The success or failure mark for a finished [status], labelled unless
  /// [showLabel] is false; null while the action is idle or running.
  static StatusIndicator? forResult(
    ActionStatus status, {
    bool showLabel = true,
  }) {
    final tone = status.resultTone;
    if (tone == null) return null;
    return StatusIndicator.tone(
      tone,
      label: showLabel ? status.resultLabel : null,
    );
  }
}
