part of 'chat_model.dart';

/// A request to the model that failed or returned an error status.
class AiServiceException implements Exception {
  /// What went wrong, with a hint on how to fix it.
  final String message;

  /// Whether sending the request again may succeed, as when the server is
  /// busy or a local model wrote a malformed tool call.
  final bool isRetryable;

  /// Creates a failure described by [message].
  const AiServiceException(this.message, {this.isRetryable = false});

  @override
  String toString() => message;
}
