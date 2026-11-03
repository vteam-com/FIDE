import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Execute panel's build target.
final selectedPlatformProvider =
    StateNotifierProvider<SelectedPlatformNotifier, FlutterPlatform>(
      (ref) =>
          SelectedPlatformNotifier(ref.watch(sharedPreferencesProvider.future)),
    );

/// The build target chosen in the Execute panel, persisted to preferences.
class SelectedPlatformNotifier extends PersistedNotifier<FlutterPlatform> {
  /// Target used until a saved choice is restored.
  static const FlutterPlatform defaultPlatform = FlutterPlatform.android;

  /// Starts at [defaultPlatform]; call [load] to restore the saved choice.
  SelectedPlatformNotifier(Future<SharedPreferences> prefs)
    : super(prefs, defaultPlatform);

  @override
  FlutterPlatform? read(SharedPreferences prefs) {
    final saved = prefs.getString(PrefKeys.selectedPlatform);
    return saved == null ? null : FlutterPlatform.fromId(saved);
  }

  /// Selects [platform] and saves it.
  Future<void> select(FlutterPlatform platform) => persist(platform);

  @override
  Future<void> write(SharedPreferences prefs, FlutterPlatform platform) =>
      prefs.setString(PrefKeys.selectedPlatform, platform.name);
}
