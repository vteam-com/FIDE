import 'package:fide/services/svg_style_inliner.css_rule.dart';
import 'package:fide/services/svg_style_inliner.css_selector.dart';
import 'package:xml/xml.dart';

/// Applies an SVG's `<style>` sheets to its elements as inline `style`
/// attributes.
///
/// `flutter_svg` ignores `<style>` elements and reads only inline styles and
/// presentation attributes, so a shape styled by class (as fCheck's graphs
/// are) loses its fill and stroke and paints solid black. Inlining the sheet
/// first makes such SVGs render as browsers draw them.
///
/// Supports simple selectors (`rect`, `*`, `.edge`, `#root`, `rect.edge`)
/// and selector lists. Rules a static picture can't use, or that need a full
/// CSS engine, are skipped: combinators, pseudo-classes such as `:hover`,
/// attribute selectors and at-rules such as `@media`.
class SvgStyleInliner {
  SvgStyleInliner._();

  /// Name of the element holding a style sheet, and of the inline attribute.
  static const String _style = 'style';

  /// Opening of a `<style>` element; SVGs without one are returned as is.
  static const String _styleTag = '<$_style';

  /// CSS comments, dropped before parsing a sheet.
  static final RegExp _comment = RegExp(r'/\*.*?\*/', dotAll: true);

  /// At-rule statements without a block, such as `@import url(a.css);`.
  static final RegExp _atStatement = RegExp(r'@[^{};]*;');

  /// A trailing `!important` flag, dropped: inline styles already win.
  static final RegExp _important = RegExp(
    r'\s*!\s*important\s*$',
    caseSensitive: false,
  );

  /// Prefix of an at-rule, such as `@media`.
  static const String _atRule = '@';

  /// Opens a rule's declaration block.
  static const String _blockOpen = '{';

  /// Closes a rule's declaration block.
  static const String _blockClose = '}';

  /// Separates the selectors of a selector list.
  static const String _selectorSeparator = ',';

  /// Separates declarations.
  static const String _declarationSeparator = ';';

  /// Separates a property name from its value.
  static const String _valueSeparator = ':';

  /// Returns [svg] with its `<style>` rules inlined into each matching
  /// element's `style` attribute; the element's own inline style keeps
  /// precedence. An SVG without rules, or that isn't well-formed XML, is
  /// returned unchanged.
  static String inline(String svg) {
    if (!svg.contains(_styleTag)) {
      return svg;
    }
    final XmlDocument document;
    try {
      document = XmlDocument.parse(svg);
    } on XmlException {
      return svg;
    }
    final rules = [
      for (final sheet in document.findAllElements(_style))
        ..._parseSheet(sheet.innerText),
    ];
    if (rules.isEmpty) {
      return svg;
    }
    rules.sort(CssRule.compareCascade);
    for (final element in document.descendantElements) {
      _applyRules(element, rules);
    }
    return document.toXmlString();
  }

  /// Sets on [element] the declarations of the matching [rules], which are
  /// sorted by cascade order, followed by its own inline style.
  static void _applyRules(XmlElement element, List<CssRule> rules) {
    final declarations = <String, String>{
      for (final rule in rules)
        if (rule.selector.matches(element)) ...rule.declarations,
    };
    if (declarations.isEmpty) {
      return;
    }
    final inline = element.getAttribute(_style);
    if (inline != null) {
      declarations.addAll(_parseDeclarations(inline));
      // Re-added last below: the SVG parser lets later attributes win, and
      // CSS rules beat the element's presentation attributes.
      element.removeAttribute(_style);
    }
    element.setAttribute(
      _style,
      [
        for (final MapEntry(:key, :value) in declarations.entries)
          '$key$_valueSeparator$value',
      ].join(_declarationSeparator),
    );
  }

  /// Parses the rules of the style sheet [css].
  static List<CssRule> _parseSheet(String css) {
    final text = css.replaceAll(_comment, '').replaceAll(_atStatement, '');
    final rules = <CssRule>[];
    var index = 0;
    while (index < text.length) {
      final open = text.indexOf(_blockOpen, index);
      if (open < 0) {
        break;
      }
      final close = _closingBrace(text, open);
      final prelude = text.substring(index, open).trim();
      if (!prelude.startsWith(_atRule)) {
        final declarations = _parseDeclarations(
          text.substring(open + 1, close),
        );
        for (final selectorText in prelude.split(_selectorSeparator)) {
          final selector = CssSelector.tryParse(selectorText);
          if (selector != null && declarations.isNotEmpty) {
            rules.add(
              CssRule(
                selector: selector,
                declarations: declarations,
                order: rules.length,
              ),
            );
          }
        }
      }
      index = close + 1;
    }
    return rules;
  }

  /// Index of the brace closing the block [text] opens at [open], skipping
  /// nested blocks (an at-rule's); the text's end when it isn't closed.
  static int _closingBrace(String text, int open) {
    var depth = 0;
    for (var index = open; index < text.length; index++) {
      final char = text[index];
      if (char == _blockOpen) {
        depth++;
      } else if (char == _blockClose && --depth == 0) {
        return index;
      }
    }
    return text.length;
  }

  /// Parses `name: value; …` declarations, by lowercase property name.
  ///
  /// Values holding a colon (such as a `data:` URL) are skipped: the SVG
  /// parser splits inline styles on every colon and would cut them short.
  static Map<String, String> _parseDeclarations(String text) {
    final declarations = <String, String>{};
    for (final declaration in text.split(_declarationSeparator)) {
      final separator = declaration.indexOf(_valueSeparator);
      if (separator < 0) {
        continue;
      }
      final name = declaration.substring(0, separator).trim().toLowerCase();
      final value = declaration
          .substring(separator + 1)
          .replaceFirst(_important, '')
          .trim();
      if (name.isNotEmpty &&
          value.isNotEmpty &&
          !value.contains(_valueSeparator)) {
        declarations[name] = value;
      }
    }
    return declarations;
  }
}
