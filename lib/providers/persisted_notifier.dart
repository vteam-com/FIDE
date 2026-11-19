import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'persisted_notifier.persisted_enum_notifier.dart';

/// The app's preferences, loaded once; every [PersistedNotifier] is wired
/// from it, and tests override it to control when they load.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// A [StateNotifier] whose value is kept in one preference across
/// launches: [load] restores the saved value and [persist] shows and saves
/// a new one. Preferences are optional: a failed load or save leaves the
/// value shown as it is, and a load ending after [persist] showed a newer
/// value keeps that one. A subclass only says how its value is [read] and
/// written ([write]).
abstract class PersistedNotifier<T> extends StateNotifier<T> {
  /// Starts at [initial] until [load] restores the value saved in [_prefs].
  PersistedNotifier(this._prefs, T initial) : super(initial);

  final Future<SharedPreferences> _prefs;

  /// How many values [persist] showed, so a [load] that ends after one
  /// doesn't overwrite it.
  int _persisted = 0;

  /// The value saved in [prefs], or null when none was.
  @protected
  T? read(SharedPreferences prefs);

  /// Saves [value] in [prefs].
  @protected
  Future<void> write(SharedPreferences prefs, T value);

  /// Restores the saved value, keeping the current one when none was saved
  /// or could be read, or [persist] showed another meanwhile.
  Future<void> load() async {
    final persisted = _persisted;
    final T? saved;
    try {
      saved = read(await _prefs);
    } catch (_) {
      return;
    }
    if (saved != null && mounted && persisted == _persisted) state = saved;
  }

  /// Shows [value] and saves it for the next launch.
  @protected
  Future<void> persist(T value) async {
    _persisted++;
    state = value;
    try {
      await write(await _prefs, value);
    } catch (_) {
      // The value is shown either way
    }
  }
}
