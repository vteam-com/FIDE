part of 'persisted_notifier.dart';

/// A [PersistedNotifier] holding one of an enum's [_values], saved under
/// [_key] by its name; a subclass only names the key, the values and the
/// starting one.
abstract class PersistedEnumNotifier<T extends Enum>
    extends PersistedNotifier<T> {
  /// Starts at [initial] until [load] restores the value saved in [prefs]
  /// under [_key]; a saved name none of [_values] has is ignored.
  PersistedEnumNotifier(super.prefs, super.initial, this._key, this._values);

  /// The preference the value's name is saved under.
  final String _key;

  /// Every value the preference may name.
  final List<T> _values;

  @override
  T? read(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    return saved == null ? null : _values.asNameMap()[saved];
  }

  /// Shows [value] and saves it for the next launch.
  Future<void> select(T value) => persist(value);

  @override
  Future<void> write(SharedPreferences prefs, T value) =>
      prefs.setString(_key, value.name);
}
