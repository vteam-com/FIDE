import 'package:fide/constants/core_constants.dart';
import 'package:flutter/foundation.dart';

/// The local model answering the AI panel, and whether it stands in for
/// the preferred [AiModel.ollama].
@immutable
class OllamaModel {
  /// Creates the model [name] in use, [isFallback] when it isn't the
  /// preferred one.
  const OllamaModel({required this.name, required this.isFallback});

  /// The model requests go to.
  final String name;

  /// Whether [name] stands in for [AiModel.ollama], which isn't
  /// downloaded or can't call tools.
  final bool isFallback;

  /// The name, noting when it stands in for the preferred model.
  String get label =>
      isFallback ? '$name (${AiModel.ollama} not available)' : name;

  @override
  bool operator ==(Object other) =>
      other is OllamaModel &&
      other.name == name &&
      other.isFallback == isFallback;

  @override
  int get hashCode => Object.hash(name, isFallback);
}
