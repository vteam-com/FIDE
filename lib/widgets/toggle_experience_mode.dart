import 'package:flutter/material.dart';

/// A reusable widget for toggling between different experience modes in the editor.
/// This widget displays an icon button that changes based on the current mode state.
class ToggleExperienceMode extends StatelessWidget {
  /// Whether the alternative mode is currently active
  final bool isAlternativeMode;

  /// Icon to show when in primary mode (default state)
  final IconData primaryIcon;

  /// Icon to show when in alternative mode
  final IconData alternativeIcon;

  /// Tooltip text for primary mode
  final String primaryTooltip;

  /// Tooltip text for alternative mode
  final String alternativeTooltip;

  /// Callback when the button is pressed
  final VoidCallback onPressed;

  /// Icon size (default: 18)
  final double iconSize;

  const ToggleExperienceMode({
    super.key,
    required this.isAlternativeMode,
    required this.primaryIcon,
    required this.alternativeIcon,
    required this.primaryTooltip,
    required this.alternativeTooltip,
    required this.onPressed,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isAlternativeMode ? alternativeIcon : primaryIcon,
        size: iconSize,
      ),
      onPressed: onPressed,
      tooltip: isAlternativeMode ? alternativeTooltip : primaryTooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
}
