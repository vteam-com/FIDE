import 'package:fide/models/project_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the dependency, code generation and fix chores', () {
    for (final (line, words) in [
      (
        'flutter pub upgrade google_sign_in_ios',
        ['flutter', 'pub', 'upgrade', 'google_sign_in_ios'],
      ),
      ('dart pub get', ['dart', 'pub', 'get']),
      ('flutter pub add http:^1.2.0', ['flutter', 'pub', 'add', 'http:^1.2.0']),
      ('flutter pub add dev:lints', ['flutter', 'pub', 'add', 'dev:lints']),
      ('flutter gen-l10n', ['flutter', 'gen-l10n']),
      ('dart fix --apply', ['dart', 'fix', '--apply']),
      ('dart format lib/main.dart', ['dart', 'format', 'lib/main.dart']),
      (
        'dart run build_runner build --delete-conflicting-outputs',
        [
          'dart',
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
      ),
      ('pod install --repo-update', ['pod', 'install', '--repo-update']),
      ('pod repo update', ['pod', 'repo', 'update']),
    ]) {
      expect(ProjectCommand.parse(line).words, words, reason: line);
    }
  });

  test('takes the line as the model may quote or space it', () {
    final command = ProjectCommand.parse(
      '  `flutter  pub add "http:^1.2.0"`  ',
    );

    expect(command.executable, 'flutter');
    expect(command.arguments, ['pub', 'add', 'http:^1.2.0']);
    expect(command.line, 'flutter pub add http:^1.2.0');
  });

  test('refuses any other command, naming those allowed', () {
    for (final line in [
      'rm -rf lib',
      'flutter run',
      'flutter clean',
      'flutter pub publish',
      'dart pub global activate evil',
      'dart pub cache clean',
      'dart run tool/script.dart',
      'pod deintegrate',
      'flutter',
      '',
    ]) {
      expect(
        () => ProjectCommand.parse(line),
        throwsFormatException,
        reason: line,
      );
    }
    expect(
      () => ProjectCommand.parse('flutter run'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(ProjectCommand.allowed),
        ),
      ),
    );
  });

  test('refuses chained commands and shell syntax', () {
    for (final line in [
      'cd ios && pod install',
      'flutter pub get; rm -rf lib',
      'flutter pub get | tee log',
      'flutter pub get > log',
      r'flutter pub add $PACKAGE',
      'flutter pub add %PACKAGE%',
      'flutter pub get `whoami`',
      'flutter pub get\nrm -rf lib',
    ]) {
      expect(
        () => ProjectCommand.parse(line),
        throwsFormatException,
        reason: line,
      );
    }
  });

  test('refuses arguments outside the project', () {
    for (final line in [
      'dart format /',
      'dart format ../other',
      'dart format lib/../../other',
      'flutter pub get --directory=/tmp',
      'flutter pub get --directory=..',
      'flutter pub add foo --path=../foo',
      'dart format C:/Users',
    ]) {
      expect(
        () => ProjectCommand.parse(line),
        throwsFormatException,
        reason: line,
      );
    }
  });

  test('lists the commands allowed compactly, for the model', () {
    expect(
      ProjectCommand.allowed,
      allOf(
        startsWith('flutter pub get|upgrade|downgrade|add|remove|'),
        contains('pod install|update'),
        contains('dart run build_runner build'),
      ),
    );
  });
}
