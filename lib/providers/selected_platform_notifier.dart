part of 'app_providers.dart';

/// The build target chosen in the Execute panel, persisted to preferences.
class SelectedPlatformNotifier extends StateNotifier<String> {
  /// Target used until a saved choice is restored.
  static final String defaultPlatform = FlutterPlatform.android.name;

  final Ref _ref;

  /// Starts at [defaultPlatform]; call [load] to restore the saved choice.
  SelectedPlatformNotifier(this._ref) : super(defaultPlatform);

  /// Restores the saved target.
  Future<void> load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    state = prefs.getString(PrefKeys.selectedPlatform) ?? defaultPlatform;
  }

  /// Selects [platform] and saves it.
  Future<void> select(String platform) async {
    state = platform;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(PrefKeys.selectedPlatform, platform);
  }
}
