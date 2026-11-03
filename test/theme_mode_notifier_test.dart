import 'package:fide/constants/constants.dart';
import 'package:fide/providers/theme_mode_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'load restores the saved mode and keeps the default without one',
    () async {
      final notifier = ThemeModeNotifier(SharedPreferences.getInstance());
      await notifier.load();
      expect(stateOf(notifier), ThemeMode.system);

      SharedPreferences.setMockInitialValues({PrefKeys.themeMode: 'dark'});
      final restored = ThemeModeNotifier(SharedPreferences.getInstance());
      await restored.load();
      expect(stateOf(restored), ThemeMode.dark);
    },
  );

  test('select applies the mode and saves it', () async {
    final notifier = ThemeModeNotifier(SharedPreferences.getInstance());

    await notifier.select(ThemeMode.light);

    expect(stateOf(notifier), ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.themeMode), 'light');
  });

  group('PersistedNotifier', () {
    test('keeps the value shown when the preferences fail', () async {
      final notifier = ThemeModeNotifier(
        Future.error(StateError('no preferences')),
      );

      await notifier.load();
      await notifier.select(ThemeMode.dark);

      expect(stateOf(notifier), ThemeMode.dark);
    });

    test('ignores a saved value it cannot decode', () async {
      SharedPreferences.setMockInitialValues({PrefKeys.themeMode: 'sepia'});
      final notifier = ThemeModeNotifier(SharedPreferences.getInstance());

      await notifier.load();

      expect(stateOf(notifier), ThemeMode.system);
    });
  });
}
