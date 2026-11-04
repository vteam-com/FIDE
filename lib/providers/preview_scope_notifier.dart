import 'package:fide/constants/constants.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which previews the Preview panel lists, persisted; see
/// [PreviewScopeNotifier].
final previewScopeProvider =
    StateNotifierProvider<PreviewScopeNotifier, PreviewScope>(
      (ref) =>
          PreviewScopeNotifier(ref.watch(sharedPreferencesProvider.future)),
    );

/// The Preview panel's Current File or Project choice, persisted to
/// preferences.
class PreviewScopeNotifier extends PersistedEnumNotifier<PreviewScope> {
  /// Starts on the current file; call [load] to restore the saved choice.
  PreviewScopeNotifier(Future<SharedPreferences> prefs)
    : super(
        prefs,
        PreviewScope.file,
        PrefKeys.previewScope,
        PreviewScope.values,
      );
}
