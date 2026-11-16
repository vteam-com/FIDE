import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// How a [StatusTone] looks, giving every badge, toast and indicator of
/// that meaning the same icon and color.
extension StatusToneStyle on StatusTone {
  /// The semantic color.
  Color get color => switch (this) {
    StatusTone.success => AppTheme.successColor,
    StatusTone.warning => AppTheme.warningColor,
    StatusTone.error => AppTheme.errorColor,
    StatusTone.info => AppTheme.infoColor,
    StatusTone.neutral => AppTheme.neutralColor,
  };

  /// [color] made readable as text or a glyph drawn straight on a surface
  /// of [colorScheme]; fills such as badges keep [color] itself.
  Color readableIn(ColorScheme colorScheme) =>
      AppTheme.readable(color, colorScheme);

  /// The glyph marking this tone.
  IconData get icon => switch (this) {
    StatusTone.success => Icons.check_circle,
    StatusTone.warning => Icons.warning,
    StatusTone.error => Icons.error,
    StatusTone.info => Icons.info,
    StatusTone.neutral => Icons.help,
  };
}
