import 'package:fide/services/app_quit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quitApp requires the app to exit, without asking', () async {
    // The test binding refuses only an exit that can't be cancelled
    await expectLater(
      quitApp(),
      throwsA(
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('Unexpected application exit request'),
        ),
      ),
    );
  });
}
