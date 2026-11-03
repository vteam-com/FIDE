part of 'core_constants.dart';

/// The local models FIDE talks to.
class AiModel {
  /// The Ollama model FIDE uses: a mixture of experts running only about
  /// 3B of its 30B parameters per token, so it answers fast and spends
  /// little energy. Fix Build edits files through Ollama tool calling, so
  /// a replacement must support tools (`llama3.1`, `qwen3`, `mistral`,
  /// ...); `codellama` does not.
  static const String ollama = 'qwen3-coder';
}
