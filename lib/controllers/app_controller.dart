// ignore: fcheck_dead_code
import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Controller for app initialization and lifecycle
class AppController {
  final Ref ref;

  AppController(this.ref);

  /// Initialize just the window manager (for use in main() before widgets)
  Future<void> initializeWindowManager() async {
    await _initializeWindowManager();
  }

  /// Initialize the app theme and MRU folders (callable from widget context)
  Future<void> initializeAppServices() async {
    await _initializeTheme();
    await _loadMruFolders();
  }

  /// Sizes, centres and shows the main window with a hidden title bar.
  Future<void> _initializeWindowManager() async {
    WidgetsFlutterBinding.ensureInitialized();

    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return;
    }
    window
      ..titleBarStyle = TitleBarStyle.hidden
      // The hidden style also hides the window buttons; keep them
      ..isWindowControlButtonsVisible = true
      ..backgroundColor = Colors.transparent.toNative()
      ..setSize(AppSize.initialWindowSize.toNative(), false)
      ..minimumSize = AppSize.minWindowSize.toNative()
      ..center()
      ..show()
      ..focus()
      // Leaving full screen hides the window buttons again; bring them back
      ..addListener((event) {
        if (event is WindowExitedFullScreenEvent) {
          window.isWindowControlButtonsVisible = true;
        }
      });
  }

  /// Initialize theme from shared preferences
  Future<void> _initializeTheme() async {
    final SharedPreferences prefs = await ref.read(
      sharedPreferencesProvider.future,
    );
    final savedThemeMode = prefs.getString(PrefKeys.themeMode);
    final themeMode = ThemeMode.values.asNameMap()[savedThemeMode];
    if (themeMode != null) {
      ref.read(themeModeProvider.notifier).state = themeMode;
    }
  }

  /// Load MRU folders, dropping ones that no longer exist
  Future<void> _loadMruFolders() {
    return ref.read(mruFoldersProvider.notifier).load();
  }

  /// Applies [themeMode] app-wide and persists it for the next launch.
  Future<void> setThemeMode(ThemeMode themeMode) async {
    ref.read(themeModeProvider.notifier).state = themeMode;
    final SharedPreferences prefs = await ref.read(
      sharedPreferencesProvider.future,
    );
    await prefs.setString(PrefKeys.themeMode, themeMode.name);
  }
}

final appControllerProvider = Provider<AppController>((ref) {
  return AppController(ref);
});
