import 'package:flutter/material.dart';

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
  static Color get successBackground => successColor.withAlpha(150);
  static Color get warningBackground => warningColor.withAlpha(150);
  static Color get errorBackground => errorColor.withAlpha(150);
  static Color get infoBackground => infoColor.withAlpha(150);
  static Color get neutralBackground => neutralColor.withAlpha(150);

  /// Text colors for semantic themes
  static const Color successText = Colors.white;
  static const Color warningText = Colors.white;
  static const Color errorText = Colors.white;
  static const Color infoText = Colors.white;
  static const Color neutralText = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ).copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: const Color(0xFFCCCCCC), width: 1.0),
        ),
        elevation: 6,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ).copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: const Color(0xFF4A4A4A), width: 1.0),
        ),
        elevation: 6,
      ),
    );
  }

  // Side panel surface color for cards/containers within the side panel
  static Color sidePanelSurface(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF) // Pure white for light mode
        : const Color(
            0xFF252526,
          ); // Slightly lighter than background for dark mode
  }

  // Side panel divider color
  static Color sidePanelDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFE5E5E5) // Light gray divider
        : const Color(0xFF3E3E42); // Dark gray divider
  }
}
