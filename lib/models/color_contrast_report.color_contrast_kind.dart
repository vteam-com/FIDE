part of 'color_contrast_report.dart';

/// Why a color falls below WCAG 2 level AA, which says how to fix it.
enum ColorContrastKind {
  /// An on-color of a color scheme the project defines does not read on
  /// its fill, such as `onPrimary` on `primary`.
  themePair,

  /// A color does not read on its background in any theme the app
  /// renders.
  lowContrast,

  /// A color reads in one theme only, such as fixed black text that
  /// vanishes on the dark theme's surface.
  oneTheme,

  /// A color made translucent, such as with `withOpacity`, that would read
  /// opaque: the opacity lets the background through.
  translucent,
}
