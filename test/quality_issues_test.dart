import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
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
  /// The hardcoded strings issue fCheck finds in a localized project
  /// whose `lib/home.dart` is [code].
  QualityIssue? hardcodedStringsIn(String code) {
    final project = Directory.systemTemp.createTempSync('quality_issues_');
    addTearDown(() => project.deleteSync(recursive: true));
    for (final MapEntry(key: path, value: content) in {
      'pubspec.yaml': _pubspec,
      'l10n.yaml': _l10n,
      'lib/l10n/app_en.arb': '{"hello": "Hello"}\n',
      'lib/home.dart': code,
    }.entries) {
      File('${project.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
    return AnalyzeFolder(project)
        .analyze()
        .issueFor(AnalyzerDomain.hardcodedStrings);
  }

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
}
