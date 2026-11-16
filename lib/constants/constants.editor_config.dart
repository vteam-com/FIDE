part of 'constants.dart';

/// Configuration constants specific to the code editor view.
class EditorConfig {
  static const double imagePreviewMaxWidthFactor = AppOpacity.emphasis;
  static const double imagePreviewMaxHeightFactor = AppOpacity.secondaryText;

  /// How far the image preview shrinks when pinched in.
  static const double imagePreviewMinScale = 0.25;

  /// How far the image preview grows when pinched out.
  static const double imagePreviewMaxScale = 8;

  /// Slices of a sound's waveform outline; the audio editor draws it at
  /// any width from these.
  static const int audioPeakCount = 4096;

  /// Slowest the audio editor plays a sound, in percent: half speed.
  static const int audioMinTempoPercent = 50;

  /// Fastest the audio editor plays a sound, in percent: double speed.
  static const int audioMaxTempoPercent = 200;

  /// Percent the audio editor's speed slider moves by in a step.
  static const int audioTempoStepPercent = 5;

  /// Most semitones the audio editor shifts a sound's pitch up or down:
  /// an octave.
  static const int audioMaxSemitones = 12;

  /// Sizes the font viewer draws its sample sentence at, smallest first.
  static const List<double> fontSampleSizes = [
    AppFontSize.caption,
    AppFontSize.label,
    AppFontSize.title,
    AppFontSize.headline,
    AppFontSize.display,
    AppFontSize.specimen,
  ];

  static const double scrollableExtentMax = 1000000;
  static const double scrollableExtentMin = 100;
  static const double lineHeight = 20;
  static const int contextLinesAboveTarget = 3;

  const EditorConfig._();
}
