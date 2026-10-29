part of 'app_providers.dart';

/// The build target chosen in the Execute panel, persisted to preferences.
class SelectedPlatformNotifier extends StateNotifier<FlutterPlatform> {
  /// Target used until a saved choice is restored.
  static const FlutterPlatform defaultPlatform = FlutterPlatform.android;

  final Ref _ref;

  /// Starts at [defaultPlatform]; call [load] to restore the saved choice.
  SelectedPlatformNotifier(this._ref) : super(defaultPlatform);

  /// Restores the saved target.
  Future<void> load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final saved = prefs.getString(PrefKeys.selectedPlatform);
    state =
        (saved == null ? null : FlutterPlatform.fromId(saved)) ??
        defaultPlatform;
  }

  /// Selects [platform] and saves it.
  Future<void> select(FlutterPlatform platform) async {
    state = platform;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(PrefKeys.selectedPlatform, platform.name);
  }
}
