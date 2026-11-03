import 'package:fide/constants/constants.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme mode, persisted; see [ThemeModeNotifier].
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider.future)),
);

/// The System / Light / Dark choice of the settings screen, persisted to
/// preferences.
class ThemeModeNotifier extends PersistedEnumNotifier<ThemeMode> {
  /// Starts following the system; call [load] to restore the saved choice.
  ThemeModeNotifier(Future<SharedPreferences> prefs)
    : super(prefs, ThemeMode.system, PrefKeys.themeMode, ThemeMode.values);
}
