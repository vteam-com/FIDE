import 'package:fide/services/svg_style_inliner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Inlines [sheet] into an SVG holding [body], and returns the inline style
/// of the element with id `target`.
String? styleOf(String sheet, String body) {
  final svg = SvgStyleInliner.inline(
    '<svg xmlns="http://www.w3.org/2000/svg">'
    '<style>$sheet</style>$body</svg>',
  );
  return XmlDocument.parse(svg).descendantElements
      .firstWhere((element) => element.getAttribute('id') == 'target')
      .getAttribute('style');
}

void main() {
  group('SvgStyleInliner.inline', () {
    test('returns an SVG without a style sheet unchanged', () {
      const svg = '<svg><rect fill="red"/></svg>';
      expect(SvgStyleInliner.inline(svg), svg);
    });

    test('returns malformed XML unchanged', () {
      const svg = '<svg><style>.a{fill:red}</style><rect';
      expect(SvgStyleInliner.inline(svg), svg);
    });

    test('inlines class rules, including selector lists', () {
      expect(
        styleOf(
          '.edge, .other { fill: none; stroke: url(#g); opacity: 0.5 }',
          '<path id="target" class="edge"/>',
        ),
        'fill:none;stroke:url(#g);opacity:0.5',
      );
    });

    test('skips pseudo-classes, combinators and at-rules', () {
      expect(
        styleOf(
          '.node { fill: white } .node:hover { fill: gold } '
              'g .node { fill: blue } '
              '@media (prefers-color-scheme: dark) { .node { fill: black } }',
          '<rect id="target" class="node"/>',
        ),
        'fill:white',
      );
    });

    test('applies rules by specificity, then source order', () {
      expect(
        styleOf(
          '#target { fill: green } .a.b { fill: blue } .a { fill: red } '
              'rect { fill: gray; stroke: black } .b { stroke: white }',
          '<rect id="target" class="a b"/>',
        ),
        'fill:green;stroke:white',
      );
    });

    test("keeps the element's own inline style winning", () {
      expect(
        styleOf(
          '/* comment */ .a { fill: red !important; stroke: gray }',
          '<rect id="target" class="a" style="fill: blue"/>',
        ),
        'fill:blue;stroke:gray',
      );
    });

    test('leaves elements no rule matches without a style', () {
      expect(
        styleOf('.a { fill: red }', '<rect id="target" class="b"/>'),
        isNull,
      );
    });
  });
}
