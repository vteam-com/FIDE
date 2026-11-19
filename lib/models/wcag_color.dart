import 'dart:math' as math;

/// A color as WCAG 2 measures contrast: 8-bit sRGB channels and an alpha,
/// packed as 0xAARRGGBB like Flutter's `Color`, without depending on
/// Flutter, so the color contrast analyzer runs anywhere Dart does.
class WcagColor {
  /// Creates the color packed in [argb], as 0xAARRGGBB.
  const WcagColor(this.argb);

  /// Creates the color of the 8-bit [alpha], [red], [green] and [blue]
  /// channels, each clamped to 0…[channelMax].
  WcagColor.fromChannels(int alpha, int red, int green, int blue)
    : argb =
          _channel(alpha) << _alphaShift |
          _channel(red) << _redShift |
          _channel(green) << _greenShift |
          _channel(blue);

  /// Largest value of a channel.
  static const int channelMax = 0xFF;

  /// Least contrast of text against its background, WCAG 2 level AA.
  static const double minTextContrast = 4.5;

  /// Least contrast of large text, icons and other glyphs that carry
  /// meaning against their background, WCAG 2 level AA.
  static const double minLargeContrast = 3;

  static const int _alphaShift = 24;

  static const int _redShift = 16;

  static const int _greenShift = 8;

  /// The channels of a color without its alpha.
  static const int _rgbMask = 0xFFFFFF;

  /// Hex digits of a color without its alpha, then with it.
  static const int _rgbDigits = 6;

  static const int _argbDigits = 8;

  static const int _hexRadix = 16;

  /// Luminance WCAG adds to both colors of a contrast ratio, for flare.
  static const double _flare = 0.05;

  /// Channel value at or under which sRGB is linear, as WCAG 2 states it.
  static const double _linearThreshold = 0.03928;

  /// Slope of sRGB's linear segment.
  static const double _linearSlope = 12.92;

  /// Offset and scale of sRGB's gamma segment.
  static const double _gammaOffset = 0.055;

  static const double _gammaScale = 1.055;

  /// sRGB's gamma exponent.
  static const double _gamma = 2.4;

  /// How much each linear channel weighs in the relative luminance.
  static const double _redWeight = 0.2126;

  static const double _greenWeight = 0.7152;

  static const double _blueWeight = 0.0722;

  /// The color as 0xAARRGGBB.
  final int argb;

  /// The alpha channel, 0 (transparent) to [channelMax] (opaque).
  int get alpha => argb >> _alphaShift & channelMax;

  /// The blue channel, 0 to [channelMax].
  int get blue => argb & channelMax;

  @override
  int get hashCode => argb.hashCode;

  /// The green channel, 0 to [channelMax].
  int get green => argb >> _greenShift & channelMax;

  /// `#RRGGBB`, or `#AARRGGBB` while translucent.
  String get hex {
    final digits = isOpaque
        ? (argb & _rgbMask).toRadixString(_hexRadix).padLeft(_rgbDigits, '0')
        : argb.toRadixString(_hexRadix).padLeft(_argbDigits, '0');
    return '#${digits.toUpperCase()}';
  }

  /// Whether nothing shows through the color.
  bool get isOpaque => alpha == channelMax;

  /// WCAG's relative luminance, 0 (black) to 1 (white); the alpha plays
  /// no part, as in Flutter's `computeLuminance`.
  double get luminance =>
      _redWeight * _linear(red) +
      _greenWeight * _linear(green) +
      _blueWeight * _linear(blue);

  /// The same color without transparency.
  WcagColor get opaque => withAlpha(channelMax);

  /// The red channel, 0 to [channelMax].
  int get red => argb >> _redShift & channelMax;

  @override
  bool operator ==(Object other) => other is WcagColor && other.argb == argb;

  /// WCAG's contrast ratio between this color and [other], from 1 to 21;
  /// draw a translucent color [over] its background first.
  double contrastWith(WcagColor other) {
    final mine = luminance + _flare;
    final theirs = other.luminance + _flare;
    return math.max(mine, theirs) / math.min(mine, theirs);
  }

  /// The opaque color seen when this one is drawn over the opaque
  /// [background]: each channel mixed by this color's alpha.
  WcagColor over(WcagColor background) {
    final share = alpha / channelMax;
    int mix(int top, int bottom) =>
        (top * share + bottom * (1 - share)).round();
    return WcagColor.fromChannels(
      channelMax,
      mix(red, background.red),
      mix(green, background.green),
      mix(blue, background.blue),
    );
  }

  @override
  String toString() => hex;

  /// The same color with [alpha], 0 to [channelMax].
  WcagColor withAlpha(int alpha) =>
      WcagColor.fromChannels(alpha, red, green, blue);

  /// The same color with [opacity], 0 to 1, as Flutter's `withOpacity`
  /// rounds it.
  WcagColor withOpacity(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * channelMax).round());

  /// [value] kept within a channel's range.
  static int _channel(int value) => value.clamp(0, channelMax);

  /// The linear light of the sRGB [channel].
  static double _linear(int channel) {
    final value = channel / channelMax;
    return value <= _linearThreshold
        ? value / _linearSlope
        : math.pow((value + _gammaOffset) / _gammaScale, _gamma).toDouble();
  }
}
