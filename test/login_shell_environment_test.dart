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
}
