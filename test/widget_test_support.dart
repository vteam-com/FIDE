import 'package:flutter_test/flutter_test.dart';

/// Lets real file and isolate work run, frame by frame, until [until]
/// holds or a while has passed.
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (until?.call() ?? attempt > 10) return;
  }
}
