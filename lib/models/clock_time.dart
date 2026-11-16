/// Formats a [Duration] the way media players show times.
extension ClockTime on Duration {
  /// Digits of the milliseconds after the seconds' point.
  static const int _millisecondDigits = 3;

  /// Digits of the seconds after the minutes.
  static const int _secondDigits = 2;

  /// This duration as minutes, seconds and milliseconds: `0:02.350`,
  /// `12:05.000`.
  String get clockLabel {
    final seconds = inSeconds.remainder(Duration.secondsPerMinute);
    final milliseconds = inMilliseconds.remainder(
      Duration.millisecondsPerSecond,
    );
    return '$inMinutes:${'$seconds'.padLeft(_secondDigits, '0')}'
        '.${'$milliseconds'.padLeft(_millisecondDigits, '0')}';
  }
}
