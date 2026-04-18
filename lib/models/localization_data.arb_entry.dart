part of 'localization_data.dart';

/// A single key-value translation entry parsed from an ARB file, optionally carrying `@`-prefixed metadata.
class ArbEntry {
  final String key;
  final String value;
  final Map<String, dynamic>? metadata;

  ArbEntry({required this.key, required this.value, this.metadata});

  factory ArbEntry.fromJson(
    String key,
    dynamic value,
    Map<String, dynamic>? metadata,
  ) {
    return ArbEntry(key: key, value: value.toString(), metadata: metadata);
  }
}
