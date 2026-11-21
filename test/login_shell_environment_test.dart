import 'dart:io';

import 'package:fide/services/login_shell_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the login shell PATH on macOS and Linux', () async {
    final overrides = await LoginShellEnvironment.load();
    if (Platform.isMacOS || Platform.isLinux) {
      expect(overrides['PATH'], contains('/usr/bin'));
      expect(overrides['PATH'], isNot(contains('__FIDE_PATH__')));
    } else {
      expect(overrides, isEmpty);
    }
  });

  group('localeOverrides', () {
    test('sets a UTF-8 LANG when no locale is named, as launchd leaves '
        'an app opened from Finder', () {
      expect(LoginShellEnvironment.localeOverrides(const {'HOME': '/'}), {
        'LANG': LoginShellEnvironment.utf8Locale,
      });
      expect(LoginShellEnvironment.localeOverrides(const {'LANG': ''}), {
        'LANG': LoginShellEnvironment.utf8Locale,
      });
    });

    test('keeps a locale the user named', () {
      for (final key in ['LC_ALL', 'LC_CTYPE', 'LANG']) {
        expect(
          LoginShellEnvironment.localeOverrides({key: 'fr_CA.UTF-8'}),
          isEmpty,
        );
      }
    });
  });
}
