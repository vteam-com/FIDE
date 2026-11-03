import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which way the Architecture view stacks its layers, persisted; see
/// [ArchitectureOrientationNotifier].
final architectureOrientationProvider =
    StateNotifierProvider<
      ArchitectureOrientationNotifier,
      ArchitectureOrientation
    >(
      (ref) => ArchitectureOrientationNotifier(
        ref.watch(sharedPreferencesProvider.future),
      ),
    );

/// The Architecture view's top down or left to right choice, persisted to
/// preferences.
class ArchitectureOrientationNotifier
    extends PersistedNotifier<ArchitectureOrientation> {
  /// Starts top down, as layers of a cake; call [load] to restore the
  /// saved choice.
  ArchitectureOrientationNotifier(Future<SharedPreferences> prefs)
    : super(prefs, ArchitectureOrientation.topDown);

  @override
  ArchitectureOrientation? read(SharedPreferences prefs) {
    final saved = prefs.getString(PrefKeys.architectureOrientation);
    return saved == null
        ? null
        : ArchitectureOrientation.values.asNameMap()[saved];
  }

  /// Switches between top down and left to right, and saves the choice
  /// for the next launch.
  Future<void> toggle() => persist(
    state == ArchitectureOrientation.topDown
        ? ArchitectureOrientation.leftToRight
        : ArchitectureOrientation.topDown,
  );

  @override
  Future<void> write(
    SharedPreferences prefs,
    ArchitectureOrientation orientation,
  ) => prefs.setString(PrefKeys.architectureOrientation, orientation.name);
}
