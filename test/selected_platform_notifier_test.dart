import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/selected_platform_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load restores the saved target, else keeps the default', () async {
    final fresh = SelectedPlatformNotifier(SharedPreferences.getInstance());
    await fresh.load();
    expect(stateOf(fresh), SelectedPlatformNotifier.defaultPlatform);

    SharedPreferences.setMockInitialValues({
      PrefKeys.selectedPlatform: FlutterPlatform.macos.name,
    });
    final restored = SelectedPlatformNotifier(SharedPreferences.getInstance());
    await restored.load();
    expect(stateOf(restored), FlutterPlatform.macos);
  });

  test('select saves the target for the next launch', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(selectedPlatformProvider.notifier)
        .select(FlutterPlatform.linux);

    expect(container.read(selectedPlatformProvider), FlutterPlatform.linux);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.selectedPlatform), 'linux');
  });
}
