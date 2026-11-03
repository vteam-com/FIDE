import 'package:fide/constants/constants.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zoom of the whole UI, [AppZoom.actualSize] for unscaled; see
/// [ZoomNotifier].
final zoomProvider = StateNotifierProvider<ZoomNotifier, double>(
  (ref) => ZoomNotifier(ref.watch(sharedPreferencesProvider.future)),
);

/// The zoom of the whole UI, stepped through [AppZoom.levels] by the View
/// menu and persisted to preferences.
class ZoomNotifier extends PersistedNotifier<double> {
  /// Starts at [AppZoom.actualSize]; call [load] to restore the saved zoom.
  ZoomNotifier(Future<SharedPreferences> prefs)
    : super(prefs, AppZoom.actualSize);

  @override
  double? read(SharedPreferences prefs) => prefs.getDouble(PrefKeys.zoom);

  /// Returns the UI to its actual size.
  Future<void> resetZoom() => setZoom(AppZoom.actualSize);

  /// Zooms the whole UI to [zoom] and saves it for the next launch.
  Future<void> setZoom(double zoom) => persist(zoom);

  @override
  Future<void> write(SharedPreferences prefs, double zoom) =>
      prefs.setDouble(PrefKeys.zoom, zoom);

  /// Enlarges the UI one zoom level.
  Future<void> zoomIn() => setZoom(AppZoom.larger(state));

  /// Shrinks the UI one zoom level.
  Future<void> zoomOut() => setZoom(AppZoom.smaller(state));
}
