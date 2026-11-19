part of 'color_contrast_report.dart';

/// What a judged color is: the kind of element, which sets the contrast
/// it needs.
enum ColorContrastElement {
  /// Text of a regular size.
  text('text', 'Text', WcagColor.minTextContrast),

  /// Text WCAG counts as large: 18 points, or 14 bold.
  largeText('text', 'Large text', WcagColor.minLargeContrast),

  /// An icon or another glyph that carries meaning.
  icon('icon', 'Icons', WcagColor.minLargeContrast),

  /// An on-color of a color scheme the project defines, on its fill.
  schemePair('', 'Scheme pairs', WcagColor.minTextContrast);

  const ColorContrastElement(this.noun, this.label, this.minimum);

  /// What a finding calls the element, such as `text`; empty when the
  /// colors' names say it.
  final String noun;

  /// What a list of the elements is called, such as `Large text`.
  final String label;

  /// Least contrast the element needs at WCAG 2 level AA.
  final double minimum;
}
