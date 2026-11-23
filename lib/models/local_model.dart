import 'package:fide/constants/core_constants.dart';

/// The local Ollama models the AI panel offers, lightest first; each
/// value's `name` is how the choice is saved.
///
/// Each one calls tools, which editing files needs, and was measured with
/// `test/ai_agent_benchmark_test.dart` before joining: a model added here
/// must call tools and do as well there as [defaultModel].
enum LocalModel {
  /// Xiaomi's MiMo V2.6, a 9B model tuned for coding agents, at half the
  /// memory of Qwen3 Coder 30B and about as fast on FIDE's agent
  /// benchmark, a little less reliable on multi-file edits (9 of 11
  /// features and 10 of 11 Fix Builds passed, against all of them).
  mimo('mimo-v2.6:9b', 'MiMo 9B', AppMetric.aiSmallModelMinMemoryGb),

  /// Qwen3 Coder 30B, a mixture of experts running about 3B of its 30B
  /// parameters per token: the most reliable of the three on the agent
  /// benchmark's edits, and the fastest writer.
  qwenCoder(
    'qwen3-coder:30b',
    'Qwen3 Coder 30B',
    AppMetric.aiLargeModelMinMemoryGb,
  ),

  /// Qwen 3.8 27B, a dense model: the only one of the three answering
  /// questions about a large project right, slower to read and write.
  qwen38('qwen3.8:27b', 'Qwen 3.8 27B', AppMetric.aiLargeModelMinMemoryGb);

  const LocalModel(this.tag, this.label, this.minMemoryGb);

  /// The model FIDE answers with until another is picked: the lightest.
  static const LocalModel defaultModel = mimo;

  /// The Ollama tag the model is downloaded and requested by.
  final String tag;

  /// The model's name in the AI panel.
  final String label;

  /// Memory of the smallest computer the model runs well on, in GB, as
  /// it takes most of it with FIDE's context window.
  final int minMemoryGb;

  /// The offered model downloaded as [tag], or null for any other model.
  static LocalModel? ofTag(String tag) =>
      values.where((model) => model.tag == tag).firstOrNull;

  /// The AI panel's name of the model downloaded as [tag]: its [label]
  /// when offered, else the tag itself.
  static String labelOf(String tag) => ofTag(tag)?.label ?? tag;
}
