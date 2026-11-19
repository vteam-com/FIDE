part of 'constants.dart';

/// Every text style of the app, in one place.
///
/// Styles come from the [AppFontSize] scale with a single emphasis weight.
/// Call sites pick a style here and may only add a state color with
/// `copyWith(color: …)`; size, weight, family and line height never vary
/// per site.
class AppTextStyle {
  /// The one emphasis weight: selected tabs, highlighted rows, titles.
  static const FontWeight _strong = FontWeight.w600;

  /// Real fixed-width font names first: the generic `monospace` alone
  /// falls back to the proportional system font on macOS.
  static const String _monoFamily = 'Menlo';

  /// Fallbacks for [_monoFamily] on other platforms.
  static const List<String> _monoFallback = [
    'Consolas',
    'DejaVu Sans Mono',
    'Courier New',
    'monospace',
  ];

  /// Badges, counters, tab labels and timestamps.
  static const TextStyle badge = TextStyle(
    fontSize: AppFontSize.badge,
    fontWeight: FontWeight.w500,
  );

  /// [badge] emphasized, such as the selected tab.
  static const TextStyle badgeStrong = TextStyle(
    fontSize: AppFontSize.badge,
    fontWeight: _strong,
  );

  /// Small text: status bars, notes, buttons inside rows.
  static const TextStyle caption = TextStyle(fontSize: AppFontSize.caption);

  /// [caption] emphasized: status labels, small headings.
  static const TextStyle captionStrong = TextStyle(
    fontSize: AppFontSize.caption,
    fontWeight: _strong,
  );

  /// Tree rows and text fields.
  static const TextStyle body = TextStyle(fontSize: AppFontSize.body);

  /// [body] emphasized, such as the selected tree row or a section
  /// heading.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: AppFontSize.body,
    fontWeight: _strong,
  );

  /// Regular reading text: paragraphs, menu entries, list titles.
  static const TextStyle label = TextStyle(fontSize: AppFontSize.label);

  /// Dialog titles and headings inside text, such as markdown's.
  static const TextStyle title = TextStyle(
    fontSize: AppFontSize.title,
    fontWeight: _strong,
  );

  /// Headline of a message screen, or a card's headline value.
  static const TextStyle headline = TextStyle(fontSize: AppFontSize.headline);

  /// The app's name on the welcome screen.
  static const TextStyle display = TextStyle(fontSize: AppFontSize.display);

  /// Emphasis alone, merged into surrounding text such as markdown bold.
  static const TextStyle strong = TextStyle(fontWeight: _strong);

  /// Strike-through alone, merged into a deleted file's name.
  static const TextStyle struckThrough = TextStyle(
    decoration: TextDecoration.lineThrough,
  );

  /// Fixed-width text for the code editor, whose size the editor sets.
  static const TextStyle monospace = TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: _monoFallback,
  );

  /// Fixed-width text for output, code snippets and paths that must line
  /// up in columns.
  static const TextStyle code = TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: AppFontSize.caption,
    height: AppLineHeight.compact,
  );

  /// Text drawn in a font file's own [family] at [fontSize] by the font
  /// viewer, in its [bold] and [italic] faces, [underline]d and
  /// [strikethrough] as toggled, in [color].
  static TextStyle fontSample({
    required String family,
    required double fontSize,
    required Color color,
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    color: color,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    decoration: TextDecoration.combine([
      if (underline) TextDecoration.underline,
      if (strikethrough) TextDecoration.lineThrough,
    ]),
    decorationColor: color,
  );

  /// Secondary lines: descriptions, details, metadata.
  static TextStyle secondary(BuildContext context) =>
      caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// A clickable link inside text.
  static TextStyle link(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TextStyle(
      color: primary,
      decoration: TextDecoration.underline,
      decorationColor: primary,
    );
  }

  /// The part of a search result that matched.
  static TextStyle match(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      backgroundColor: colorScheme.primaryContainer,
      color: colorScheme.onPrimaryContainer,
    );
  }

  /// The line numbers of the code editor and of a diff, in the secondary
  /// text color: dimmer than the code, yet readable.
  static TextStyle lineNumber(BuildContext context) => TextStyle(
    letterSpacing: -1,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  /// Syntax colors layered over the highlight.js theme in the code editor.
  static Map<String, TextStyle> codeTokens(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final keyword = isDark
        ? Colors.purple[AppShade.soft]
        : Colors.purple[AppShade.strong];
    final number = isDark
        ? Colors.blue[AppShade.soft]
        : Colors.blue[AppShade.strong];
    return {
      'root': TextStyle(
        backgroundColor: colorScheme.surface,
        color: colorScheme.onSurface,
      ),
      'comment': TextStyle(
        color: isDark
            ? Colors.green[AppShade.soft]
            : Colors.green[AppShade.deep],
      ),
      'keyword': TextStyle(color: keyword, fontWeight: _strong),
      'string': TextStyle(
        color: isDark ? Colors.red[AppShade.soft] : Colors.red[AppShade.strong],
      ),
      'number': TextStyle(color: number),
      'variable': TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      'title.class_': TextStyle(color: number, fontWeight: _strong),
      'title.function_': TextStyle(
        color: isDark
            ? Colors.blue[AppShade.muted]
            : Colors.blue[AppShade.strong],
      ),
      // In the code's own color: the bold sets operators apart
      'operator': strong,
    };
  }

  const AppTextStyle._();
}
