import 'dart:math' show pow;
import 'package:flutter/material.dart';

/// Utility functions for color manipulation
class ColorUtils {
  /// Returns the inverse (complementary) color of the given color.
  /// The inverse is calculated by subtracting each RGB component from 255
  /// while preserving the alpha channel.
  static Color inverse(final Color color) {
    return Color.fromARGB(
      (color.a * 255).toInt(),
      255 - (color.r * 255).toInt(),
      255 - (color.g * 255).toInt(),
      255 - (color.b * 255).toInt(),
    );
  }

  /// Returns a color with adjusted brightness.
  /// factor > 1.0 makes the color brighter, factor < 1.0 makes it darker.
  static Color adjustBrightness(Color color, double factor) {
    assert(factor >= 0, 'Brightness factor must be non-negative');

    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withLightness(
      (hsl.lightness * factor).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }

  /// Returns a color with adjusted saturation.
  /// factor > 1.0 increases saturation, factor < 1.0 decreases it.
  static Color adjustSaturation(Color color, double factor) {
    assert(factor >= 0, 'Saturation factor must be non-negative');

    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withSaturation(
      (hsl.saturation * factor).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }

  /// Returns the luminance of a color (perceived brightness).
  /// Returns a value between 0.0 (black) and 1.0 (white).
  static double luminance(Color color) {
    // Convert RGB to linear color space
    double toLinear(double component) {
      component /= 255.0;
      return component <= 0.03928
          ? component / 12.92
          : pow((component + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = toLinear(color.r * 255);
    final g = toLinear(color.g * 255);
    final b = toLinear(color.b * 255);

    // Calculate luminance using standard coefficients
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Returns whether the color is considered "dark" based on its luminance.
  static bool isDark(Color color) {
    return luminance(color) < 0.5;
  }

  /// Returns whether the color is considered "light" based on its luminance.
  static bool isLight(Color color) {
    return !isDark(color);
  }

  /// Returns a contrasting color (black or white) that provides good contrast
  /// against the given background color.
  static Color contrastingColor(Color background) {
    return isDark(background) ? Colors.white : Colors.black;
  }
}
