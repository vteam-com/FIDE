import 'package:fide/services/svg_style_inliner.css_selector.dart';

/// One selector of an SVG `<style>` sheet with the declarations it sets, as
/// in `.edge { fill: none; stroke: url(#g) }`; a rule listing several
/// selectors yields one [CssRule] per selector.
class CssRule {
  /// Creates the rule giving elements matching [selector] the
  /// [declarations], the [order]-th rule of its sheet.
  const CssRule({
    required this.selector,
    required this.declarations,
    required this.order,
  });

  /// Elements the rule applies to.
  final CssSelector selector;

  /// Property names mapped to their values, in source order.
  final Map<String, String> declarations;

  /// Position in the sheet: of two equally specific rules, the later wins.
  final int order;

  /// Orders rules by the CSS cascade: less specific first, then source
  /// order, so applying them in turn leaves the winning value last.
  static int compareCascade(CssRule a, CssRule b) {
    final bySpecificity = CssSelector.compareSpecificity(
      a.selector,
      b.selector,
    );
    return bySpecificity != 0 ? bySpecificity : a.order.compareTo(b.order);
  }
}
