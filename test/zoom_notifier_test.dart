import 'package:fide/constants/constants.dart';
import 'package:fide/providers/zoom_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ZoomNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifier = ZoomNotifier(SharedPreferences.getInstance());
  });

  test('load restores the saved zoom', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.zoom: 1.5});
    final restored = ZoomNotifier(SharedPreferences.getInstance());

    await restored.load();

    expect(stateOf(restored), 1.5);
  });

  test('zooms in and out one level and saves the zoom', () async {
    await notifier.zoomIn();
    expect(stateOf(notifier), AppZoom.larger(AppZoom.actualSize));

    await notifier.zoomOut();
    await notifier.zoomOut();
    expect(stateOf(notifier), AppZoom.smaller(AppZoom.actualSize));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(PrefKeys.zoom), stateOf(notifier));
  });

  test('resetZoom returns to the actual size', () async {
    await notifier.setZoom(AppZoom.levels.last);

    await notifier.resetZoom();

    expect(stateOf(notifier), AppZoom.actualSize);
  });

  test('the provider starts unscaled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(zoomProvider), AppZoom.actualSize);
  });
}
