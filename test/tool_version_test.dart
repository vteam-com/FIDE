import 'package:fide/models/tool_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the version printed after a tool name', () {
    const flutter = 'Flutter 3.24.0 • channel stable\nDart 3.5.0 • DevTools';

    expect(versionAfter('Flutter', flutter), '3.24.0');
    expect(versionAfter('Dart', flutter), '3.5.0');
    expect(versionAfter('git version', 'git version 2.39.3 (Apple)'), '2.39.3');
    expect(versionAfter('Flutter', 'flutter: command not found'), isNull);
  });
}
