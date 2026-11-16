import 'package:xml/xml.dart';

/// A simple CSS selector of an SVG `<style>` sheet: an optional element type
/// (or `*`), followed by any number of `.class` and `#id` parts, as in
/// `rect`, `.edge`, `#root` or `rect.fileNode`.
class CssSelector {
  /// Creates the selector matching elements named [type] (any element when
  /// null) that carry every class of [classes] and every id of [ids].
  const CssSelector({this.type, this.classes = const [], this.ids = const []});

  /// Simple selectors: an optional type or `*`, then `.class` / `#id` parts.
  static final RegExp _simpleSelector = RegExp(
    r'^(?<type>\*|[A-Za-z][\w-]*)?(?<parts>(?:[.#][\w-]+)*)$',
  );

  /// Group of [_simpleSelector] holding the element type, if any.
  static const String _typeGroup = 'type';

  /// Group of [_simpleSelector] holding the `.class` and `#id` parts.
  static const String _partsGroup = 'parts';

  /// One `.class` or `#id` part of a simple selector.
  static final RegExp _part = RegExp(r'[.#][\w-]+');

  /// Splits the class names of a `class` attribute.
  static final RegExp _whitespace = RegExp(r'\s+');

  /// The universal selector, matching any element type.
  static const String _universal = '*';

  /// Prefix of a class part.
  static const String _classPrefix = '.';

  /// Element name the selector requires; null matches any element.
  final String? type;

  /// Class names the element must all carry.
  final List<String> classes;

  /// Ids the element must have.
  final List<String> ids;

  /// Parses [text] as a simple selector; null for anything a static picture
  /// can't use or this parser doesn't support: combinators (`g rect`),
  /// pseudo-classes (`.edge:hover`) and attribute selectors (`[x]`).
  static CssSelector? tryParse(String text) {
    final match = _simpleSelector.firstMatch(text.trim());
    if (match == null || match.group(0)!.isEmpty) {
      return null;
    }
    final type = match.namedGroup(_typeGroup);
    final classes = <String>[];
    final ids = <String>[];
    for (final part in _part.allMatches(match.namedGroup(_partsGroup)!)) {
      final token = part.group(0)!;
      (token.startsWith(_classPrefix) ? classes : ids).add(token.substring(1));
    }
    return CssSelector(
      type: type == _universal ? null : type,
      classes: classes,
      ids: ids,
    );
  }

  /// Whether [element] matches this selector.
  bool matches(XmlElement element) {
    if (type != null && element.localName != type) {
      return false;
    }
    if (ids.any((id) => element.getAttribute('id') != id)) {
      return false;
    }
    if (classes.isEmpty) {
      return true;
    }
    final elementClasses = (element.getAttribute('class') ?? '')
        .split(_whitespace)
        .toSet();
    return classes.every(elementClasses.contains);
  }

  /// Orders selectors by CSS specificity: ids first, then classes, then the
  /// element type; negative when [a] is less specific than [b].
  static int compareSpecificity(CssSelector a, CssSelector b) {
    final byIds = a.ids.length.compareTo(b.ids.length);
    if (byIds != 0) {
      return byIds;
    }
    final byClasses = a.classes.length.compareTo(b.classes.length);
    if (byClasses != 0) {
      return byClasses;
    }
    return a._typeCount.compareTo(b._typeCount);
  }

  /// How many element types the selector names: none or one.
  int get _typeCount => type == null ? 0 : 1;
}
