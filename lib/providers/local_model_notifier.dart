import 'package:fide/constants/constants.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The local model picked in the AI panel, persisted; see
/// [LocalModelNotifier].
final localModelProvider =
    StateNotifierProvider<LocalModelNotifier, LocalModel>(
      (ref) => LocalModelNotifier(ref.watch(sharedPreferencesProvider.future)),
    );

/// The local model the AI answers with, picked in the AI panel's footer
/// and persisted to preferences.
class LocalModelNotifier extends PersistedEnumNotifier<LocalModel> {
  /// Starts at [LocalModel.defaultModel]; call [load] to restore the
  /// saved choice.
  LocalModelNotifier(Future<SharedPreferences> prefs)
    : super(
        prefs,
        LocalModel.defaultModel,
        PrefKeys.localModel,
        LocalModel.values,
      );
}
