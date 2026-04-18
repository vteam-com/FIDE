import 'package:fide/models/app_theme.dart';
import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

/// A reusable badge widget that displays status or feedback information.
///
/// This widget can be used for status indicators, feedback messages, and other
/// small informational badges throughout the application.
class BadgeStatus extends StatelessWidget {
  const BadgeStatus({
    super.key,
    required this.text,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.fontSize = AppFontSize.badge,
    this.fontWeight = FontWeight.w500,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.small,
      vertical: AppSpacing.micro,
    ),
    this.borderRadius = AppRadius.tiny,
    this.showIcon = false,
  });

  /// Creates a pre-configured success badge.
  factory BadgeStatus.success({
    required String text,
    double fontSize = AppFontSize.badge,
    bool showIcon = false,
  }) {
    return BadgeStatus(
      text: text,
      backgroundColor: AppTheme.successColor,
      textColor: AppTheme.successText.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      showIcon: showIcon,
    );
  }

  /// Creates a pre-configured warning badge.
  factory BadgeStatus.warning({
    required String text,
    double fontSize = AppFontSize.badge,
    bool showIcon = false,
  }) {
    return BadgeStatus(
      text: text,
      backgroundColor: AppTheme.warningColor,
      textColor: AppTheme.warningText.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      showIcon: showIcon,
    );
  }

  /// Creates a pre-configured error badge.
  factory BadgeStatus.error({
    required String text,
    double fontSize = AppFontSize.badge,
    bool showIcon = false,
  }) {
    return BadgeStatus(
      text: text,
      backgroundColor: AppTheme.errorColor,
      textColor: AppTheme.errorText.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      showIcon: showIcon,
    );
  }

  /// Creates a pre-configured info badge.
  factory BadgeStatus.info({
    required String text,
    double fontSize = AppFontSize.badge,
    bool showIcon = false,
  }) {
    return BadgeStatus(
      text: text,
      backgroundColor: AppTheme.infoColor,
      textColor: AppTheme.infoText.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      showIcon: showIcon,
    );
  }
  factory BadgeStatus.neutral({
    required String text,
    double fontSize = AppFontSize.badge,
    bool showIcon = false,
  }) {
    return BadgeStatus(
      text: text,
      backgroundColor: AppTheme.neutralColor,
      textColor: AppTheme.neutralText.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      showIcon: showIcon,
    );
  }

  /// Creates a pre-configured addition badge (for Git diff stats).
  factory BadgeStatus.addition({
    required int count,
    double fontSize = AppFontSize.caption,
  }) {
    return _fromDiffCount(
      count: count,
      prefix: '+',
      backgroundColor: AppTheme.successColor,
      textColor: AppTheme.successText,
      fontSize: fontSize,
    );
  }

  /// Creates a pre-configured deletion badge (for Git diff stats).
  factory BadgeStatus.deletion({
    required int count,
    double fontSize = AppFontSize.caption,
  }) {
    return _fromDiffCount(
      count: count,
      prefix: '-',
      backgroundColor: AppTheme.errorColor,
      textColor: AppTheme.errorText,
      fontSize: fontSize,
    );
  }

  /// The background color of the badge.
  final Color backgroundColor;

  /// The border radius of the badge.
  final double borderRadius;

  /// The font size of the text.
  final double fontSize;

  /// The font weight of the text.
  final FontWeight fontWeight;

  /// The padding around the text inside the badge.
  final EdgeInsetsGeometry padding;

  /// Whether to show an appropriate icon for the badge type.
  final bool showIcon;

  /// The text to display in the badge.
  final String text;

  /// The text color of the badge.
  final Color textColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withAlpha(AppAlpha.badgeFill),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        border: Border.all(
          color: _borderColor,
          width: AppBorderWidth.emphasized,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Icon(
              _icon,
              size: fontSize * AppOpacity.prominent,
              color: textColor,
            ),
            const SizedBox(width: AppSpacing.narrow),
          ],
          Text(
            text,
            style: TextStyle(
              decoration: TextDecoration.none,
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Creates a solid border color from the background color by removing opacity
  Color get _borderColor {
    return Color.fromRGBO(
      (backgroundColor.r * AppMetric.colorChannelMax).round(),
      (backgroundColor.g * AppMetric.colorChannelMax).round(),
      (backgroundColor.b * AppMetric.colorChannelMax).round(),
      1.0, // Full opacity
    );
  }

  /// Builds a compact badge for Git diff addition or deletion counts.
  static BadgeStatus _fromDiffCount({
    required int count,
    required String prefix,
    required Color backgroundColor,
    required Color textColor,
    required double fontSize,
  }) {
    return BadgeStatus(
      text: '$prefix$count',
      backgroundColor: backgroundColor,
      textColor: textColor.withAlpha(AppAlpha.badgeText),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny,
        vertical: AppSize.borderThin,
      ),
    );
  }

  /// Gets the appropriate icon for the badge type based on background color.
  IconData? get _icon {
    if (!showIcon) return null;

    if (backgroundColor == AppTheme.successColor) return Icons.check_circle;
    if (backgroundColor == AppTheme.warningColor) return Icons.warning;
    if (backgroundColor == AppTheme.errorColor) return Icons.error;
    if (backgroundColor == AppTheme.infoColor) return Icons.info;
    if (backgroundColor == AppTheme.neutralColor) return Icons.help;

    return null;
  }
}
