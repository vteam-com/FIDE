import 'package:fide/models/app_theme.dart';
import 'package:flutter/material.dart';

/// The meaning of a status shown to the user, giving every badge, toast
/// and indicator of that meaning the same icon and color.
enum StatusTone {
  /// Something finished or is available.
  success(Icons.check_circle, AppTheme.successColor),

  /// Something needs attention but still works.
  warning(Icons.warning, AppTheme.warningColor),

  /// Something failed or is missing.
  error(Icons.error, AppTheme.errorColor),

  /// Neutral information.
  info(Icons.info, AppTheme.infoColor),

  /// No particular meaning.
  neutral(Icons.help, AppTheme.neutralColor);

  const StatusTone(this.icon, this.color);

  /// The semantic color.
  final Color color;

  /// The glyph marking this tone.
  final IconData icon;
}
