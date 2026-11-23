import 'package:fide/models/local_model.dart';
import 'package:flutter/foundation.dart';

/// The local model answering the AI panel, whether it stands in for the
/// [preferred] one, and the models downloaded.
@immutable
class OllamaModel {
  /// Creates the model [name] in use, [isFallback] when it isn't the
  /// [preferred] one, with the [downloaded] models.
  const OllamaModel({
    required this.name,
    required this.isFallback,
    required this.preferred,
    required this.downloaded,
  });

  /// The model requests go to.
  final String name;

  /// Whether [name] stands in for [preferred], which isn't downloaded or
  /// can't call tools.
  final bool isFallback;

  /// Tag of the model picked in the AI panel.
  final String preferred;

  /// Tags of the models downloaded.
  final Set<String> downloaded;

  /// The model's name, noting when it stands in for the preferred model.
  String get label {
    final shown = LocalModel.labelOf(name);
    return isFallback
        ? '$shown (${LocalModel.labelOf(preferred)} not available)'
        : shown;
  }

  /// Whether [model] is the one requests go to.
  bool isInUse(LocalModel model) => model.tag == name;

  /// Whether [model] is downloaded.
  bool isDownloaded(LocalModel model) => downloaded.contains(model.tag);

  @override
  bool operator ==(Object other) =>
      other is OllamaModel &&
      other.name == name &&
      other.isFallback == isFallback &&
      other.preferred == preferred &&
      setEquals(other.downloaded, downloaded);

  @override
  int get hashCode => Object.hash(
    name,
    isFallback,
    preferred,
    Object.hashAllUnordered(downloaded),
  );
}
