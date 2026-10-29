import 'package:fide/models/project_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectPaths.ensureCleanable', () {
    const paths = ProjectPaths('/src/app');

    test('refuses the project the app was built from', () {
      expect(
        () => paths.ensureCleanable(
          executable: '/src/app/build/macos/Build/Products/Debug/App.app/Contents/MacOS/App',
        ),
        throwsA(isA<String>()),
      );
    });

    test('allows other projects', () {
      expect(
        () => paths.ensureCleanable(executable: '/Applications/App.app/App'),
        returnsNormally,
      );
      expect(
        () => paths.ensureCleanable(executable: '/src/app2/build/App'),
        returnsNormally,
      );
    });
  });
}
