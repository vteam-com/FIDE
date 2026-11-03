import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/providers/architecture_orientation_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts top down and restores the saved orientation', () async {
    final notifier = ArchitectureOrientationNotifier(
      SharedPreferences.getInstance(),
    );
    await notifier.load();
    expect(stateOf(notifier), ArchitectureOrientation.topDown);

    SharedPreferences.setMockInitialValues({
      PrefKeys.architectureOrientation: 'leftToRight',
    });
    final restored = ArchitectureOrientationNotifier(
      SharedPreferences.getInstance(),
    );
    await restored.load();
    expect(stateOf(restored), ArchitectureOrientation.leftToRight);
  });

  test('toggle flips the orientation and saves it', () async {
    final notifier = ArchitectureOrientationNotifier(
      SharedPreferences.getInstance(),
    );

    await notifier.toggle();
    expect(stateOf(notifier), ArchitectureOrientation.leftToRight);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.architectureOrientation), 'leftToRight');

    await notifier.toggle();
    expect(stateOf(notifier), ArchitectureOrientation.topDown);
  });
}
