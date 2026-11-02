part of 'chat_model.dart';

/// Stops the model requests of one feature, such as one chat reply or one
/// translation task, without touching the requests of the others.
class AiCancelToken {
  /// Completed by [cancel].
  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] was called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes once [cancel] is called, aborting the requests sent with
  /// this token.
  Future<void> get whenCancelled => _cancelled.future;

  /// Aborts the requests in flight with this token, which then throw an
  /// [AiCancelledException], as do later ones; Ollama stops generating
  /// when the connection closes. Calling it again does nothing.
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  /// Throws an [AiCancelledException] once [cancel] was called.
  void throwIfCancelled() {
    if (isCancelled) throw const AiCancelledException();
  }
}
