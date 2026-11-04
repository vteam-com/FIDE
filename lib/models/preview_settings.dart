import 'package:flutter/foundation.dart';

/// How the preview host renders the previews, as the Preview panel sets
/// it.
@immutable
class PreviewSettings {
  /// Creates the settings.
  const PreviewSettings({
    required this.pixelRatio,
    required this.maxWidth,
    required this.maxHeight,
    required this.fallbackHeight,
    required this.fallbackBrightness,
    this.brightness,
  });

  /// Device pixels per logical pixel of the frames: the screen's times the
  /// panel's zoom, so zoomed frames stay sharp.
  final double pixelRatio;

  /// Widest a preview without a width of its own lays out.
  final double maxWidth;

  /// Tallest a preview without a height of its own lays out.
  final double maxHeight;

  /// The height of a preview that sets none and has no natural height,
  /// such as a scroll view.
  final double fallbackHeight;

  /// The brightness forced on every preview; null to use each preview's
  /// own.
  final Brightness? brightness;

  /// The brightness of previews that set none: FIDE's.
  final Brightness fallbackBrightness;

  /// The settings message for the host.
  Map<String, Object?> toJson() => {
    'type': 'settings',
    'pixelRatio': pixelRatio,
    'maxWidth': maxWidth,
    'maxHeight': maxHeight,
    'fallbackHeight': fallbackHeight,
    'brightness': brightness?.name,
    'fallbackBrightness': fallbackBrightness.name,
  };

  @override
  bool operator ==(Object other) =>
      other is PreviewSettings &&
      other.pixelRatio == pixelRatio &&
      other.maxWidth == maxWidth &&
      other.maxHeight == maxHeight &&
      other.fallbackHeight == fallbackHeight &&
      other.brightness == brightness &&
      other.fallbackBrightness == fallbackBrightness;

  @override
  int get hashCode => Object.hash(
    pixelRatio,
    maxWidth,
    maxHeight,
    fallbackHeight,
    brightness,
    fallbackBrightness,
  );
}
