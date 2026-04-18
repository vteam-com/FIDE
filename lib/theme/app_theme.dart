// ignore: fcheck_dead_code
import 'package:fide/constants.dart';
import 'package:flutter/material.dart';

/// Represents `AppTheme`.
class AppTheme {
  // Single seed color for consistent theming
  static const Color _seedColor = Colors.blue;

  /// Semantic status colors for consistent use across BadgeStatus, MessageBox, and LocalizationPanel
  /// These colors work with both light and dark themes
  static const Color successColor = Color(
    0xFF1B5E20,
  ); // Dark green for success states
  static const Color warningColor = Color(
    0xFFE65100,
  ); // Dark orange for warning states
  static const Color errorColor = Color(
    0xFFD32F2F,
  ); // Dark red for error states
  static const Color infoColor = Color(0xFF1976D2); // Dark blue for info states
  static const Color neutralColor = Color(
    0xFF616161,
  ); // Dark grey for neutral states

  /// Light backgrounds for semantic color themes (with alpha for theme adaptation)
  static Color get successBackground =>
      successColor.withAlpha(AppAlpha.badgeFill);

  /// Returns the warning background color used by semantic status UI.
  static Color get warningBackground =>
      warningColor.withAlpha(AppAlpha.badgeFill);

  /// Returns the error background color used by semantic status UI.
  static Color get errorBackground => errorColor.withAlpha(AppAlpha.badgeFill);

  /// Returns the info background color used by semantic status UI.
  static Color get infoBackground => infoColor.withAlpha(AppAlpha.badgeFill);

  /// Returns the neutral background color used by semantic status UI.
  static Color get neutralBackground =>
      neutralColor.withAlpha(AppAlpha.badgeFill);

  /// Text colors for semantic themes
  static const Color successText = Colors.white;
  static const Color warningText = Colors.white;
  static const Color errorText = Colors.white;
  static const Color infoText = Colors.white;
  static const Color neutralText = Colors.white;

  /// Builds the shared theme configuration used by both theme modes.
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color popupBorderColor,
  }) {
    return ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    ).copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.medium)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: AppIconSize.mediumLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: popupBorderColor, width: AppSize.borderThin),
        ),
        elevation: AppSpacing.small,
      ),
    );
  }

  /// Builds the application's light theme.
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      popupBorderColor: AppColor.popupBorderLight,
    );
  }

  /// Builds the application's dark theme.
  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      popupBorderColor: AppColor.popupBorderDark,
    );
  }

  /// Returns the side-panel surface color for cards and nested containers.
  static Color sidePanelSurface(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? AppColor
              .sidePanelSurfaceLight // Pure white for light mode
        : AppColor
              .sidePanelSurfaceDark; // Slightly lighter than background for dark mode
  }

  /// Returns the side-panel divider color for the active brightness.
  static Color sidePanelDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? AppColor
              .sidePanelDividerLight // Light gray divider
        : AppColor.sidePanelDividerDark; // Dark gray divider
  }
}
