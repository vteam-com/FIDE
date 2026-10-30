import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:flutter/material.dart';

/// A small tinted label marking a status, a count or a short code.
///
/// Every badge of the app looks the same: a fill and outline in [color]
/// with light text; only [large] badges, used as the headline value of a
/// stat card, are bigger.
class BadgeStatus extends StatelessWidget {
  /// Creates a badge showing [text] in [color].
  const BadgeStatus({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.large = false,
  });

  /// Creates a badge with the color, and optionally the icon, of [tone].
  BadgeStatus.tone(
    StatusTone tone, {
    super.key,
    required this.text,
    bool showIcon = false,
    this.large = false,
  }) : color = tone.color,
       icon = showIcon ? tone.icon : null;

  /// Creates a success badge.
  BadgeStatus.success({
    Key? key,
    required String text,
    bool showIcon = false,
    bool large = false,
  }) : this.tone(
         StatusTone.success,
         key: key,
         text: text,
         showIcon: showIcon,
         large: large,
       );

  /// Creates a warning badge.
  BadgeStatus.warning({
    Key? key,
    required String text,
    bool showIcon = false,
    bool large = false,
  }) : this.tone(
         StatusTone.warning,
         key: key,
         text: text,
         showIcon: showIcon,
         large: large,
       );

  /// Creates an error badge.
  BadgeStatus.error({
    Key? key,
    required String text,
    bool showIcon = false,
    bool large = false,
  }) : this.tone(
         StatusTone.error,
         key: key,
         text: text,
         showIcon: showIcon,
         large: large,
       );

  /// Creates an info badge.
  BadgeStatus.info({
    Key? key,
    required String text,
    bool showIcon = false,
    bool large = false,
  }) : this.tone(
         StatusTone.info,
         key: key,
         text: text,
         showIcon: showIcon,
         large: large,
       );

  /// Creates a `+count` badge for lines added in a Git diff.
  BadgeStatus.addition({Key? key, required int count})
    : this.tone(StatusTone.success, key: key, text: '+$count');

  /// Creates a `-count` badge for lines removed in a Git diff.
  BadgeStatus.deletion({Key? key, required int count})
    : this.tone(StatusTone.error, key: key, text: '-$count');

  /// Creates a `score%` badge: error below
  /// [AppMetric.criticalScoreThreshold], warning below
  /// [AppMetric.warningScoreThreshold], success otherwise.
  BadgeStatus.score(int score, {Key? key, bool large = false})
    : this.tone(
        score < AppMetric.criticalScoreThreshold
            ? StatusTone.error
            : score < AppMetric.warningScoreThreshold
            ? StatusTone.warning
            : StatusTone.success,
        key: key,
        text: '$score%',
        large: large,
      );

  /// The fill and outline color.
  final Color color;

  /// Glyph before [text]; none when null.
  final IconData? icon;

  /// Whether the badge is the headline value of a card.
  final bool large;

  /// The text to display in the badge.
  final String text;

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? AppFontSize.title : AppFontSize.badge;
    final textColor = Colors.white.withAlpha(AppAlpha.badgeText);
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.badgeFill),
        borderRadius: BorderRadius.circular(AppRadius.tiny),
        border: Border.all(color: color, width: AppBorderWidth.emphasized),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.narrow,
        children: [
          if (icon != null)
            Icon(icon, size: fontSize * AppOpacity.prominent, color: textColor),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              decoration: TextDecoration.none,
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
