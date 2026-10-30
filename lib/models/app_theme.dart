// ignore: fcheck_dead_code

import 'package:fide/constants/constants.dart';
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
    0xFFF57C00,
  ); // Orange for warning states, kept clear of the error red
  static const Color errorColor = Color(
    0xFFD32F2F,
  ); // Dark red for error states
  static const Color infoColor = Color(0xFF1976D2); // Dark blue for info states
  static const Color neutralColor = Color(
    0xFF616161,
  ); // Dark grey for neutral states

  /// Fill behind content marked as an error, such as a broken dependency.
  static Color get errorBackground => errorColor.withAlpha(AppAlpha.badgeFill);

  /// Builds the shared theme configuration used by both theme modes.
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color popupBorderColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData.from(
      colorScheme: colorScheme,
      useMaterial3: true,
    ).copyWith(
      // One look for every TabBar: full-width underline, primary when selected
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontSize: AppFontSize.badge,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppFontSize.badge,
          fontWeight: FontWeight.w500,
        ),
      ),
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
        : AppColor.sidePanelSurfaceDark; // Slightly lighter than background for dark mode
  }

  /// The style of every secondary line: descriptions, captions, metadata.
  static TextStyle secondaryText(BuildContext context) => TextStyle(
    fontSize: AppFontSize.caption,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  /// Returns the side-panel divider color for the active brightness.
  static Color sidePanelDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? AppColor
              .sidePanelDividerLight // Light gray divider
        : AppColor.sidePanelDividerDark; // Dark gray divider
  }

  /// Radial gradient the workspace panel islands float on.
  ///
  /// A shaded core, darker than every surface tone, opens out to a primary
  /// glow at the window edges, so the gaps between islands read clearly in
  /// both modes.
  static BoxDecoration workspaceBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).brightness == Brightness.light
        ? colorScheme.surfaceDim
        : colorScheme.surfaceContainerLowest;
    return BoxDecoration(
      gradient: RadialGradient(
        radius: AppGradient.workspaceRadius,
        colors: [
          Color.alphaBlend(
            colorScheme.shadow.withValues(alpha: AppOpacity.workspaceShade),
            base,
          ),
          Color.alphaBlend(
            colorScheme.primary.withValues(alpha: AppOpacity.workspaceGlow),
            base,
          ),
        ],
        stops: const [
          AppGradient.workspaceCoreStop,
          AppGradient.workspaceEdgeStop,
        ],
      ),
    );
  }

  /// Vertical surface gradient behind the full-screen welcome, loading and
  /// create-project views.
  static BoxDecoration screenBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.surface,
          colorScheme.surfaceContainerHighest.withValues(
            alpha: AppOpacity.divider,
          ),
        ],
      ),
    );
  }
}
