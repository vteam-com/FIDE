import 'package:fide/models/arb_message.dart';
import 'package:fide/models/unique_name.dart';

/// Picks the ARB key of each new message: the existing key of the same
/// message, or a fresh one that clashes with no key, Dart keyword or
/// member of the generated class; collects the entries to add.
class ArbKeys {
  /// Starts from the entries of the template ARB file [arb].
  ArbKeys(Map<String, dynamic> arb) {
    for (final MapEntry(:key, :value) in arb.entries) {
      if (key.startsWith('@') || value is! String) continue;
      _keys.add(key);
      _keyByMessage.putIfAbsent(value, () => key);
    }
  }

  /// Members of the generated localizations class a key would hide.
  static const Set<String> _generatedMembers = {
    'delegate',
    'localizationsDelegates',
    'of',
    'supportedLocales',
    'localeName',
    'hashCode',
    'noSuchMethod',
    'runtimeType',
    'toString',
  };

  /// Entries to add to the template ARB file, metadata included.
  final Map<String, Object> added = {};

  final Map<String, String> _keyByMessage = {};

  final Set<String> _keys = {};

  /// The key of [message], added to [added] when new.
  String keyFor(ArbMessage message) {
    final existing = _keyByMessage[message.text];
    if (existing != null) return existing;

    final safeBase = safeIdentifier(
      message.keyBase,
      suffix: 'Text',
      reserved: _generatedMembers,
    );
    final key = uniqueName(safeBase, _keys.contains);
    _keys.add(key);
    _keyByMessage[message.text] = key;
    added[key] = message.text;
    final metadata = message.metadata;
    if (metadata.isNotEmpty) added['@$key'] = metadata;
    return key;
  }
}
