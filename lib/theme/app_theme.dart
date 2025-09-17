import 'package:flutter/material.dart';

class AppTheme {
  // Single seed color for consistent theming
  static const Color _seedColor = Colors.blue;

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
