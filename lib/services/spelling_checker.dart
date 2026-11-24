import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/spelling_finding.dart';

/// Finds the words of Dart text that no known word matches, splitting
/// names such as `adaptiveLandscape` and `adaptive_landscape` into their
/// words first, and suggests the closest known word for each.
class SpellingChecker {
  /// Words of the English list and the programming terms, lowercase, which
  /// a word must match; a project's own words go in the allowlist.
  static const Set<String> programmingTerms = {
    'addressdetails',
    'anonymized',
    'antimeridian',
    'api',
    'app',
    'appleid',
    'apps',
    'args',
    'async',
    'atan',
    'auth',
    'autocomplete',
    'autofocus',
    'backend',
    'banksy',
    'bool',
    'browsable',
    'builder',
    'cache',
    'cli',
    'config',
    'const',
    'cooldown',
    'coords',
    'cov',
    'ctx',
    'cupertino',
    'dart',
    'datetime',
    'debounce',
    'debounced',
    'denormalised',
    'dev',
    'dir',
    'dirs',
    'dispose',
    'double',
    'draggable',
    'dropdown',
    'enum',
    'epsg',
    'exif',
    'falsy',
    'faq',
    'fcheck',
    'filesystem',
    'firebaseapp',
    'firebasestorage',
    'firestore',
    'fixme',
    'flutter',
    'fullscreen',
    'future',
    'geocode',
    'geocoded',
    'geocoder',
    'geocodes',
    'geocoding',
    'geolocation',
    'geolocator',
    'geopoint',
    'geotagged',
    'gif',
    'glanceable',
    'google',
    'googleapis',
    'googleusercontent',
    'grayscale',
    'hardcoded',
    'hardcoding',
    'heic',
    'hitbox',
    'html',
    'http',
    'https',
    'id',
    'ids',
    'idx',
    'ifd',
    'img',
    'init',
    'initialiser',
    'initialisers',
    'instagram',
    'int',
    'ios',
    'itunes',
    'jpeg',
    'jpg',
    'json',
    'keychain',
    'latlong',
    'letterbox',
    'lib',
    'lifecycle',
    'linux',
    'lng',
    'lon',
    'luma',
    'macos',
    'main',
    'megapixel',
    'metadata',
    'mixin',
    'nominatim',
    'nullable',
    'openid',
    'openstreetmap',
    'overspray',
    'pano',
    'pdf',
    'plugin',
    'png',
    'popup',
    'precache',
    'precached',
    'precaching',
    'pub',
    'pubspec',
    'px',
    'rasterised',
    'rasterises',
    'rasterized',
    'recognisably',
    'rects',
    'regex',
    'relayouts',
    'repo',
    'resync',
    'rgb',
    'riverpod',
    'roundtrip',
    'roundtripped',
    'screenshots',
    'scriptable',
    'scrollable',
    'sdk',
    'signin',
    'skia',
    'smoothstep',
    'snackbar',
    'src',
    'standalone',
    'state',
    'stateful',
    'stateless',
    'stream',
    'svg',
    'timeline',
    'tmp',
    'todo',
    'tooltip',
    'trackpad',
    'ui',
    'uid',
    'uint',
    'unawaited',
    'uncompress',
    'undecodable',
    'unrecognised',
    'unregister',
    'unregistering',
    'uploader',
    'upsample',
    'url',
    'urls',
    'username',
    'usr',
    'utf',
    'var',
    'void',
    'vsync',
    'vteam',
    'webp',
    'website',
    'widget',
    'widgets',
    'workflow',
    'writeln',
    'www',
    'yaml',
  };

  /// Splits a name into its words: runs of capitals, a capital and the
  /// lowercase letters after it, and lowercase runs.
  static final RegExp _word = RegExp(r'[A-Z]+(?![a-z])|[A-Z]?[a-z]+');

  /// A name: letters, digits and underscores, starting with a letter.
  static final RegExp _name = RegExp(r'[A-Za-z][A-Za-z0-9_]*');

  /// The words a match of [known] is taken from, lowercase.
  final Set<String> known;

  /// The suggestion of each unknown word checked, by the word.
  final Map<String, String?> _nearest = {};

  /// Known words by their first letter, for [nearest] to scan.
  late final Map<String, List<String>> _byInitial = _indexByInitial(known);

  /// Creates a checker matching words against [known], lowercase.
  SpellingChecker(this.known);

  /// The unknown words of [text], the file at [path]: each word of each
  /// name at least [AppMetric.spellingMinWordChars] long that no known
  /// word matches, with its line and the closest known word.
  ///
  /// Returns the findings, how many words were checked and the distinct
  /// ones among them.
  ({List<SpellingFinding> findings, int checked, Set<String> words}) check(
    String path,
    String text,
  ) {
    final findings = <SpellingFinding>[];
    final words = <String>{};
    var checked = 0;
    final lines = text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      for (final name in _name.allMatches(lines[index])) {
        for (final word in _word.allMatches(name.group(0)!)) {
          final written = word.group(0)!;
          final lower = written.toLowerCase();
          if (lower.length < AppMetric.spellingMinWordChars) continue;
          checked++;
          words.add(lower);
          if (known.contains(lower) ||
              _notWords(written) ||
              _isInflection(lower)) {
            continue;
          }
          findings.add(
            SpellingFinding(
              path: path,
              line: index + 1,
              word: lower,
              suggestion: nearest(lower),
            ),
          );
        }
      }
    }
    return (findings: findings, checked: checked, words: words);
  }

  /// Whether [word] is a known word with a regular ending added: `s`, `es`,
  /// `ed` or `ing`, with the base's final `e` or `y` changed where English
  /// does, as in `widgets`, `boxes`, `copied` or `studying`.
  bool _isInflection(String word) {
    for (final base in _basesOf(word)) {
      if (base.length >= AppMetric.spellingMinWordChars &&
          known.contains(base)) {
        return true;
      }
    }
    return false;
  }

  /// The base words [word] could be a regular form of: its ending removed,
  /// with an `e` or a `y` put back where English changes the base, as
  /// `copies` and `copied` from `copy`, `boxes` from `box`.
  static Iterable<String> _basesOf(String word) sync* {
    for (final ending in _endings) {
      if (!word.endsWith(ending.suffix)) continue;
      final stem = word.substring(0, word.length - ending.suffix.length);
      yield stem;
      yield '${stem}e';
      if (ending.yBase) yield '${stem}y';
    }
  }

  /// The regular endings of English words, and whether removing one may
  /// leave a base ending in `y` (`copies`, `copied`): `ies` and `ied` do.
  static const List<({String suffix, bool yBase})> _endings = [
    (suffix: 'ies', yBase: true),
    (suffix: 'ied', yBase: true),
    (suffix: 'es', yBase: false),
    (suffix: 's', yBase: false),
    (suffix: 'ed', yBase: false),
    (suffix: 'ing', yBase: false),
  ];

  /// Whether [written], unknown, is not a word to check: an acronym in
  /// capitals, or a hex colour code such as `ffd`.
  static bool _notWords(String written) =>
      written == written.toUpperCase() || _hexColor.hasMatch(written);

  /// A hex colour code's digits: letters a to f only.
  static final RegExp _hexColor = RegExp(r'^[a-fA-F]+$');

  /// The known word closest to [word], within
  /// [AppMetric.spellingMaxSuggestionDistance] edits, among the known words
  /// starting with the same letter, as a typo keeps its first letter; null
  /// when none is. Cached per word.
  String? nearest(String word) {
    if (_nearest.containsKey(word)) return _nearest[word];
    String? best;
    var bestDistance = AppMetric.spellingMaxSuggestionDistance + 1;
    for (final candidate in _byInitial[word[0]] ?? const <String>[]) {
      if ((candidate.length - word.length).abs() >= bestDistance) continue;
      final distance = _distance(word, candidate, bestDistance - 1);
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
        if (distance == 1) break;
      }
    }
    return _nearest[word] = best;
  }

  /// [words] grouped by their first letter, in one pass.
  static Map<String, List<String>> _indexByInitial(Set<String> words) {
    final index = <String, List<String>>{};
    for (final word in words) {
      if (word.isEmpty) continue;
      index.putIfAbsent(word[0], () => []).add(word);
    }
    return index;
  }

  /// Rows of the edit-distance table kept at once: the current, the previous
  /// and the one before a swap of neighbours looks back to.
  static const int _rollingRows = 3;

  /// How many letters back a swap of neighbours looks, to the row and
  /// column it started from.
  static const int _swapLookBack = 2;

  /// Edits between [a] and [b], counting a swap of neighbours as one, or
  /// [limit] + 1 once they are known to be more than [limit] apart.
  static int _distance(String a, String b, int limit) {
    final rows = List.generate(
      _rollingRows,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      final current = rows[i % _rollingRows];
      final previous = rows[(i - 1) % _rollingRows];
      current[0] = i;
      var rowMinimum = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var value = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (i >= _swapLookBack &&
            j >= _swapLookBack &&
            a[i - 1] == b[j - _swapLookBack] &&
            a[i - _swapLookBack] == b[j - 1]) {
          final swapped =
              rows[(i - _swapLookBack) % _rollingRows][j - _swapLookBack] + 1;
          if (swapped < value) value = swapped;
        }
        current[j] = value;
        if (value < rowMinimum) rowMinimum = value;
      }
      if (rowMinimum > limit) return limit + 1;
    }
    return rows[a.length % _rollingRows][b.length];
  }
}
