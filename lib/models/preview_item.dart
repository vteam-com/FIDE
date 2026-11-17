import 'package:flutter/foundation.dart';

/// One preview the host renders; its frames stream in separately, see
/// `previewFramesProvider`.
@immutable
class PreviewItem {
  /// Creates the item.
  const PreviewItem({
    required this.function,
    required this.line,
    required this.group,
    this.annotation = 0,
    this.name,
  });

  /// The item the host describes in [json].
  factory PreviewItem.fromJson(Map<String, Object?> json) => PreviewItem(
    function: json['function'] as String? ?? '',
    line: json['line'] as int? ?? 1,
    group: json['group'] as String? ?? '',
    annotation: json['annotation'] as int? ?? 0,
    name: json['name'] as String?,
  );

  /// The function, static method or constructor building the preview.
  final String function;

  /// Its 1-based line in the file.
  final int line;

  /// The position of the preview's annotation among its function's.
  final int annotation;

  /// The preview's group, `Default` unless the annotation sets one.
  final String group;

  /// The preview's name, from its annotation.
  final String? name;

  /// What the Preview panel titles the preview: its name, else its
  /// function.
  String get title => name ?? function;
}
