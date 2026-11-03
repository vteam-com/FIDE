import 'package:fide/models/ollama_model.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local model in use, as the last Ollama setup check of
/// [ollamaStatusProvider] resolved it; changes with each check.
final ollamaModelProvider = Provider<OllamaModel>((ref) {
  ref.watch(ollamaStatusProvider);
  final client = ref.read(ollamaClientProvider);
  return OllamaModel(name: client.model, isFallback: client.isFallbackModel);
});
