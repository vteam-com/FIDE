import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/app_providers.dart';
import '../providers/ui_state_providers.dart';

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

  /// Initialize window manager with default settings
  Future<void> _initializeWindowManager() async {
    WidgetsFlutterBinding.ensureInitialized();

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// Initialize theme from shared preferences
  Future<void> _initializeTheme() async {
    final SharedPreferences prefs = await ref.read(
      sharedPreferencesProvider.future,
    );
    final savedThemeMode = prefs.getString('theme_mode');
    if (savedThemeMode != null) {
      final themeMode = _parseThemeMode(savedThemeMode);
      ref.read(themeModeProvider.notifier).state = themeMode;
    }
  }

  /// Load MRU folders and try to auto-load first project
  Future<void> _loadMruFolders() async {
    final SharedPreferences prefs = await ref.read(
      sharedPreferencesProvider.future,
    );
    final mruList = prefs.getStringList('mru_folders') ?? [];

    // Filter out folders that don't exist
    final validMruFolders = mruList
        .where((path) => Directory(path).existsSync())
        .toList();

    // Update the provider
    ref.read(mruFoldersProvider.notifier).state = validMruFolders;
  }

  /// Parse theme mode string to ThemeMode enum
  ThemeMode _parseThemeMode(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Save theme mode to shared preferences
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final SharedPreferences prefs = await ref.read(
      sharedPreferencesProvider.future,
    );
    final themeString = themeMode.name;
    await prefs.setString('theme_mode', themeString);
  }
}

final appControllerProvider = Provider<AppController>((ref) {
  return AppController(ref);
});
