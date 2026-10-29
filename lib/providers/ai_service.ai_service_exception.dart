part of 'ai_service.dart';

/// A request to the local model that failed or returned an error status.
class AiServiceException implements Exception {
  /// What went wrong, with a hint on how to fix it.
  final String message;

  /// Creates a failure described by [message].
  const AiServiceException(this.message);

  @override
  String toString() => message;
}
