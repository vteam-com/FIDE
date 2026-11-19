import 'dart:io';

import 'package:fide/models/color_contrast_report.dart';
import 'package:fide/services/color_contrast_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// An app with a light theme only.
const String _lightApp = '''
void main() => runApp(MaterialApp(theme: ThemeData(), home: const Home()));
''';

/// An app with both themes.
const String _bothThemesApp = '''
void main() => runApp(
  MaterialApp(theme: ThemeData(), darkTheme: ThemeData.dark(), home: const Home()),
);
''';

/// Analyzes a project whose `lib/main.dart` is [app] followed by a
/// widget whose build returns [body].
ColorContrastReport _analyze(String body, {String app = _lightApp}) {
  final folder = Directory.systemTemp.createTempSync('color_contrast_');
  addTearDown(() => folder.deleteSync(recursive: true));
  File(p.join(folder.path, 'lib', 'main.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync('''
$app
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return $body;
  }
}
''');
  return const ColorContrastAnalyzer().analyze(folder.path);
}

/// The kinds of what [report] found, in order.
List<ColorContrastKind> _kinds(ColorContrastReport report) => [
  for (final finding in report.findings) finding.failure!,
];

void main() {
  group('a color on a background the code paints', () {
    test('is judged in every theme the app renders', () {
      final report = _analyze('''
Container(
  color: Colors.white,
  child: Text('Muted', style: TextStyle(color: Colors.grey)),
)''');
      expect(_kinds(report), [ColorContrastKind.lowContrast]);
      expect(
        report.findings.single.message,
        'Colors.grey text (#9E9E9E) on Colors.white (#FFFFFF): 2.6:1, '
        'needs 4.5:1',
      );
    });

    test('passes when it reads', () {
      final report = _analyze('''
Container(
  decoration: BoxDecoration(color: Colors.white),
  child: Text('Body', style: TextStyle(color: Colors.black87)),
)''');
      expect(report.findings, isEmpty);
    });

    test('needs 3:1 only as large text or an icon', () {
      const grey = 'Color(0xFF8A8A8A)';
      expect(
        _kinds(
          _analyze('''
ColoredBox(
  color: Colors.white,
  child: Column(children: [
    Text('Title', style: TextStyle(color: $grey, fontSize: 24)),
    Icon(Icons.add, color: $grey),
    Text('Body', style: TextStyle(color: $grey)),
  ]),
)'''),
        ),
        [ColorContrastKind.lowContrast],
      );
    });

    test("reads the project's constants and a widget's own colors", () {
      final report = _analyze(
        '''
Scaffold(
  appBar: AppBar(backgroundColor: Colors.yellow, foregroundColor: Colors.white),
  body: Text('Hint', style: TextStyle(color: AppColors.hint)),
)''',
        app:
            '''
$_lightApp
abstract final class AppColors {
  static const Color hint = Color(0xFFBDBDBD);
}
''',
      );
      expect(
        [for (final finding in report.findings) finding.foreground],
        ['Colors.white', 'AppColors.hint'],
      );
    });

    test("uses a widget's Material 3 default fill", () {
      final report = _analyze('''
SnackBar(content: Text('Saved', style: TextStyle(color: Colors.black)))''');
      expect(report.findings.single.background, 'the SnackBar background');
    });

    test('is skipped when the background cannot be read', () {
      final report = _analyze('''
Column(children: [
  Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: brand)),
    child: Text('On a gradient', style: TextStyle(color: Colors.white)),
  ),
  Container(color: brandColor, child: Icon(Icons.star, color: Colors.white)),
  Chip(label: Text('Tag', style: TextStyle(color: Colors.white))),
])''');
      expect(report.findings, isEmpty);
    });
  });

  test('reads every way to write a color', () {
    final report = _analyze('''
Container(
  color: Colors.white,
  child: Column(children: [
    Text('a', style: TextStyle(color: Color.fromARGB(255, 158, 158, 158))),
    Text('b', style: TextStyle(color: Color.fromRGBO(189, 189, 189, 1))),
    Text('c', style: TextStyle(color: Color.from(alpha: 1, red: 0.5, green: 0.5, blue: 0.5))),
    Text('d', style: TextStyle(color: Colors.grey[400]!)),
    Text('e', style: TextStyle(color: Colors.black.withValues(alpha: 0.3))),
  ]),
)''');
    expect(
      [for (final finding in report.findings) finding.foregroundColor.hex],
      ['#9E9E9E', '#BDBDBD', '#808080', '#BDBDBD', '#B2B2B2'],
    );
  });

  group('what the app paints', () {
    test("takes the fill a theme gives a kind of widget", () {
      final report = _analyze(
        "Scaffold(body: Text('Night', style: TextStyle(color: Colors.black87)))",
        app: '''
void main() => runApp(
  MaterialApp(
    theme: ThemeData(scaffoldBackgroundColor: Colors.black),
    home: const Home(),
  ),
);
''',
      );
      expect(report.findings.single.background, 'Colors.black');
    });

    test("reads a filled text field's fill", () {
      final report = _analyze('''
Scaffold(
  backgroundColor: Colors.black,
  body: TextField(
    decoration: InputDecoration(filled: true, fillColor: Colors.white),
    style: TextStyle(color: Colors.black),
  ),
)''');
      expect(report.findings, isEmpty);
    });

    test("does not judge what the project's painting widgets show", () {
      final report = _analyze(
        "Scaffold(body: Panel(child: Text('On the panel', style: TextStyle(color: Colors.white))))",
        app:
            '''
$_lightApp
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.indigo, child: child);
}
''',
      );
      expect(report.findings, isEmpty);
    });

    test('judges an app set to one theme in that theme alone', () {
      const body = "Text('Title', style: TextStyle(color: Colors.black))";
      String app(String mode) =>
          _bothThemesApp.replaceFirst('home:', 'themeMode: $mode, home:');
      expect(_analyze(body, app: app('ThemeMode.dark')).findings, isEmpty);
      expect(
        _kinds(
          _analyze(body, app: app('isDark ? ThemeMode.dark : ThemeMode.light')),
        ),
        [ColorContrastKind.oneTheme],
      );
    });

    test('exempts the colors of disabled controls, as WCAG does', () {
      final report = _analyze(
        '''
Container(
  color: Colors.white,
  child: Text('Off', style: TextStyle(color: AppColors.textDisabled)),
)''',
        app:
            '''
$_lightApp
abstract final class AppColors {
  static const Color textDisabled = Color(0xFFBDBDBD);
}
''',
      );
      expect(report.findings, isEmpty);
    });
  });

  group('what the report counts', () {
    test('every element judged, passing or not, and those not judged', () {
      final report = _analyze('''
Container(
  color: Colors.white,
  child: Column(children: [
    Text('Body', style: TextStyle(color: Colors.black87)),
    Text('Muted', style: TextStyle(color: Colors.grey)),
    Icon(Icons.add, color: Colors.black),
    Text('Picked', style: TextStyle(color: picked)),
  ]),
)''');
      expect(report.checks, hasLength(3));
      expect(report.findings, hasLength(1));
      expect(report.of(ColorContrastElement.icon).single.passes, isTrue);
      expect(report.unjudged, 1);
      expect(report.score, 66);
    });

    test('every color the code writes, the most used first', () {
      final report = _analyze(
        '''
Column(children: [
  Text('a', style: TextStyle(color: AppColors.brand)),
  Text('b', style: TextStyle(color: AppColors.brand)),
  Icon(Icons.star, color: AppColors.brand),
  Text('c', style: TextStyle(color: Colors.grey)),
  Text('d', style: TextStyle(color: Color(0xFF9E9E9E))),
  Text('e', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
])''',
        app:
            '''
$_bothThemesApp
abstract final class AppColors {
  static const Color brand = Color(0xFF3D5AFE);
}
''',
      );
      final colors = report.colors;
      // The constant counts where it is read, not where it is defined
      expect(colors.first.names, {'AppColors.brand': 3});
      expect(colors.first.colors.single.hex, '#3D5AFE');
      final grey = colors.firstWhere((color) => color.count == 2);
      expect(grey.names, {'Colors.grey': 1, 'Color(0xFF9E9E9E)': 1});
      final primary = colors.singleWhere(
        (color) => color.names.containsKey('colorScheme.primary'),
      );
      expect(primary.colors.map((color) => color.hex), ['#6750A4', '#D0BCFF']);
    });

    test('the scheme of each theme, one built for either brightness', () {
      final report = _analyze(
        'Placeholder()',
        app: '''
void main() => runApp(
  MaterialApp(theme: build(Brightness.light), darkTheme: build(Brightness.dark)),
);

ThemeData build(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  ),
);
''',
      );
      expect(
        [for (final scheme in report.schemes) scheme.theme],
        ['light', 'dark'],
      );
      for (final scheme in report.schemes) {
        expect(scheme.origin, 'Generated from the seed Colors.teal');
        expect(scheme.line, 6);
      }
      expect(report.schemes.last.roles.isDark, isTrue);
    });

    test("a scheme picked at run time can't be read, and says so", () {
      final report = _analyze(
        'Placeholder()',
        app: '''
void main() => runApp(
  MaterialApp(theme: ThemeData(colorSchemeSeed: seeds[picked])),
);
''',
      );
      expect(
        report.schemes.single.origin,
        "Can't be read here: Material 3's default is assumed",
      );
      expect(report.schemes.single.line, 2);
    });
  });

  group('a color with nothing painted around it', () {
    test('counts when the dark theme alone loses it', () {
      const body = "Text('Title', style: TextStyle(color: Colors.black))";
      expect(_analyze(body).findings, isEmpty);
      final report = _analyze(body, app: _bothThemesApp);
      expect(_kinds(report), [ColorContrastKind.oneTheme]);
      expect(report.findings.single.theme, 'dark');
    });

    test('counts when an opacity fades it', () {
      final report = _analyze('''
Text(
  'Secondary',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
  ),
)''');
      expect(_kinds(report), [ColorContrastKind.translucent]);
    });

    test(
      'does not count a light color that needs a fill it gets elsewhere',
      () {
        final report = _analyze(
          "Text('On a badge', style: TextStyle(color: Colors.white))",
          app: _bothThemesApp,
        );
        expect(report.findings, isEmpty);
      },
    );
  });

  test("judges the on-colors of the project's color scheme", () {
    final report = _analyze(
      'Placeholder()',
      app: '''
void main() => runApp(
  MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        primary: Colors.yellow,
      ),
    ),
    home: const Home(),
  ),
);
''',
    );
    expect(_kinds(report), [ColorContrastKind.themePair]);
    expect(report.findings.single.foreground, 'onPrimary');
    expect(report.findings.single.line, 6);
  });

  test('skips what an ignore comment covers, as fCheck does', () {
    const muted = '''
Container(
  color: Colors.white,
  child: Text('Muted', style: TextStyle(color: Colors.grey)), // ignore: fcheck_color_contrast
)''';
    expect(_analyze(muted).findings, isEmpty);
    expect(
      _analyze(
        muted.replaceFirst(' // ignore: fcheck_color_contrast', ''),
        app: '// ignore: fcheck_color_contrast\n\$_lightApp',
      ).findings,
      isEmpty,
    );
  });
}
