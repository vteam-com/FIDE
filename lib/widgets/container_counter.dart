import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';

/// The one count pill: a [BadgeStatus] showing [count], explained by
/// [tooltip] on hover and acting on [onTap]; neutral for a plain count of
/// items, orange with the counted thing's [icon] for a rule breach.
class ContainerCounter extends StatelessWidget {
  /// Creates the neutral pill counting [count] items.
  const ContainerCounter({
    super.key,
    required this.count,
    this.tooltip,
    this.onTap,
  }) : tone = StatusTone.neutral,
       icon = null;

  /// Creates the warning pill: [count] breaches of what [icon] names,
  /// explained by [tooltip].
  const ContainerCounter.warning({
    super.key,
    required IconData this.icon,
    required this.count,
    required String this.tooltip,
    this.onTap,
  }) : tone = StatusTone.warning;

  /// The number shown.
  final int count;

  /// The glyph naming what is counted; none when null.
  final IconData? icon;

  /// Called when the pill is clicked; null when it isn't clickable.
  final VoidCallback? onTap;

  /// The pill's meaning and color.
  final StatusTone tone;

  /// What the count means, shown on hover; none when null.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tooltip = this.tooltip;
    final pill = Clickable(
      onTap: onTap,
      child: BadgeStatus(text: '$count', color: tone.color, icon: icon),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}
