part of 'constants.dart';

/// Shared base text styles; callers add size and color with `copyWith`.
class AppTextStyle {
  /// Fixed-width text for output and code that must line up in columns.
  ///
  /// Names a real font first: the generic `monospace` alone falls back to
  /// the proportional system font on macOS.
  static const TextStyle monospace = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: [
      'Consolas',
      'DejaVu Sans Mono',
      'Courier New',
      'monospace',
    ],
  );

  const AppTextStyle._();
}
