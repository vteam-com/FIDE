import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:flutter_test/flutter_test.dart';

/// A localized project's pubspec.
const String _pubspec = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
flutter:
  generate: true
''';

/// The project's gen-l10n configuration.
const String _l10n = '''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''';

void main() {
  /// fCheck's analysis of a localized project holding [files], by path.
  ProjectMetrics analyzed(Map<String, String> files) {
    final project = Directory.systemTemp.createTempSync('quality_issues_');
    addTearDown(() => project.deleteSync(recursive: true));
    for (final MapEntry(key: path, value: content) in {
      'pubspec.yaml': _pubspec,
      'l10n.yaml': _l10n,
      'lib/l10n/app_en.arb': '{"hello": "Hello"}\n',
      ...files,
    }.entries) {
      File('${project.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
    return AnalyzeFolder(project).analyze();
  }

  /// The hardcoded strings issue fCheck finds in a localized project
  /// whose `lib/home.dart` is [code].
  QualityIssue? hardcodedStringsIn(String code) =>
      analyzed({'lib/home.dart': code})
          .issueFor(AnalyzerDomain.hardcodedStrings);

  test('hardcoded strings a string fix rewrites offer the review, not a '
      'second AI fix', () {
    final issue = hardcodedStringsIn('''
import 'package:flutter/widgets.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => const Text('Welcome to the app');
}
''')!;

    expect(issue.quickFixes, isNotEmpty);
    expect(issue.aiActionLabel, isNull);
  });

  test('hardcoded strings no fix rewrites are localized with AI', () {
    final issue = hardcodedStringsIn('''
import 'package:flutter/widgets.dart';

class Home extends StatelessWidget {
  const Home({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext _) => Text(greeting(name));
}

String greeting(String name) => 'Welcome to the app, \$name';
''')!;

    expect(issue.quickFixes, isEmpty);
    expect(issue.aiActionLabel, 'Localize with AI');
  });

  test('a file with more than one public class is listed, explained and '
      'split by code, not the AI, unless it opts out', () {
    final metrics = analyzed({
      'lib/shapes.dart': 'class Shapes {}\n\nclass Circle {}\n',
      'lib/menu.dart':
          '// ignore: fcheck_one_class_per_file\n'
          'class Menu {}\n\nclass Item {}\n',
    });
    final issue = metrics.issueFor(AnalyzerDomain.oneClassPerFile)!;

    expect(issue.findings.map((finding) => (finding.path, finding.text)), [
      (metrics.absolutePathOf('lib/shapes.dart'), '2 public classes'),
    ]);
    expect(issue.quickFixes, [QuickFix.splitClasses]);
    expect(issue.aiActionLabel, isNull);
    expect(issue.guidance, contains('private (`_FooState`)'));
    expect(issue.guidance, contains('// ignore: fcheck_one_class_per_file'));
  });
}
