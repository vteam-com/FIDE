import 'package:flutter/material.dart';

/// A reusable badge widget that displays status or feedback information.
///
/// This widget can be used for status indicators, feedback messages, and other
/// small informational badges throughout the application.
class BadgeStatus extends StatelessWidget {
  /// The text to display in the badge.
  final String text;

  /// The background color of the badge.
  final Color backgroundColor;

  /// The text color of the badge.
  final Color textColor;

  /// The font size of the text.
  final double fontSize;

  /// The font weight of the text.
  final FontWeight fontWeight;

  /// The padding around the text inside the badge.
  final EdgeInsetsGeometry padding;

  /// The border radius of the badge.
  final double borderRadius;

  const BadgeStatus({
    super.key,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.fontSize = 10,
    this.fontWeight = FontWeight.w500,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.borderRadius = 4,
  });

  /// Creates a solid border color from the background color by removing opacity
  Color get _borderColor {
    return Color.fromRGBO(
      (backgroundColor.r * 255).round(),
      (backgroundColor.g * 255).round(),
      (backgroundColor.b * 255).round(),
      1.0, // Full opacity
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withAlpha(150),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          decoration: TextDecoration.none,
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Creates a pre-configured success badge.
  factory BadgeStatus.success({required String text, double fontSize = 10}) {
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.green.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
    );
  }

  /// Creates a pre-configured warning badge.
  factory BadgeStatus.warning({required String text, double fontSize = 10}) {
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.orange.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
    );
  }

  /// Creates a pre-configured error badge.
  factory BadgeStatus.error({required String text, double fontSize = 10}) {
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
    );
  }

  /// Creates a pre-configured info badge.
  factory BadgeStatus.info({required String text, double fontSize = 10}) {
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.blue.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
    );
  }

  factory BadgeStatus.neutral({required String text, double fontSize = 10}) {
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.grey.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
    );
  }

  /// Creates a pre-configured addition badge (for Git diff stats).
  factory BadgeStatus.addition({required int count, double fontSize = 12}) {
    final text = '+$count';
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.green.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    );
  }

  /// Creates a pre-configured deletion badge (for Git diff stats).
  factory BadgeStatus.deletion({required int count, double fontSize = 12}) {
    final text = '-$count';
    return BadgeStatus(
      text: text,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white.withAlpha(160),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    );
  }
}
