import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light(useMaterial3: true);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    return baseTheme.copyWith(
      colorScheme: ColorScheme.light(
        primary: Colors.blue.shade800,
        secondary: Colors.blue.shade600,
        surface: Colors.grey.shade100,
      ),
      dividerColor: Colors.grey.shade300,
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.grey.shade800, width: 1),
    );

    return baseTheme.copyWith(
      colorScheme: ColorScheme.dark(
        primary: Colors.blue.shade300,
        secondary: Colors.blue.shade200,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white70,
      ),
      dividerColor: Colors.grey.shade800,
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF1E1E1E),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
