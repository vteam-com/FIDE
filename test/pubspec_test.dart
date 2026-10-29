import 'package:fide/models/pubspec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads values containing colons in full', () {
    final pubspec = Pubspec.parse('''
name: demo
version: 1.2.3+4
description: "An app: the best one"
''');

    expect(pubspec.name, 'demo');
    expect(pubspec.version, '1.2.3+4');
    expect(pubspec.description, 'An app: the best one');
  });

  test('detects Flutter from the SDK dependency or a flutter section', () {
    expect(
      Pubspec.parse('dependencies:\n  flutter:\n    sdk: flutter\n').isFlutter,
      isTrue,
    );
    expect(Pubspec.parse('name: x\nflutter:\n').isFlutter, isTrue);
    expect(
      Pubspec.parse('name: x\ndependencies:\n  path: any\n').isFlutter,
      isFalse,
    );
  });

  test('reads the generate flag and dependencies', () {
    final pubspec = Pubspec.parse('''
dependencies:
  intl: any
flutter:
  generate: true
''');

    expect(pubspec.generatesLocalizations, isTrue);
    expect(pubspec.dependsOn('intl'), isTrue);
    expect(pubspec.dependsOn('flutter_localizations'), isFalse);
  });

  test('invalid YAML yields an empty pubspec', () {
    final pubspec = Pubspec.parse('name: [unclosed');

    expect(pubspec.name, isNull);
    expect(pubspec.isFlutter, isFalse);
  });
}
