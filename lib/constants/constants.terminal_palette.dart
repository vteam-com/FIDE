part of 'constants.dart';

/// ANSI colour palette for the embedded terminal widget.
class TerminalPalette {
  static const Color background = Color(0xFF1E1E1E);
  static final Color red = Colors.redAccent;
  static const Color green = Color(0xFF5AF78E);
  static const Color yellow = Color(0xFFF3F99D);
  static const Color blue = Color(0xFF57C7FF);
  static const Color magenta = Color(0xFFFF6AC1);
  static const Color cyan = Color(0xFF9AEDFE);
  static const Color white = Color(0xFFF1F1F0);

  /// Dim grey text, such as hints and timestamps, light enough to read on
  /// [background].
  static const Color brightBlack = Color(0xFF8A8A8A);
  static const Color brightWhite = Color(0xFFFFFFFF);

  /// The caret.
  static const Color cursor = brightWhite;

  /// Behind the selected text: a translucent blue.
  static const Color selection = Color(0x642196F3);

  /// Behind the matches of a search.
  static const Color searchHit = Color(0xFFFFEB3B);

  /// Behind the current match of a search.
  static const Color searchHitCurrent = Color(0xFFFF9800);

  /// The text of a search match, on [searchHit] or [searchHitCurrent].
  static const Color searchHitText = Color(0xFF000000);

  const TerminalPalette._();
}
