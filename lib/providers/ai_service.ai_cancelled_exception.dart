part of 'ai_service.dart';

/// A request to the local model stopped by [AIService.cancel].
class AiCancelledException extends AiServiceException {
  /// Creates the failure of a cancelled request.
  const AiCancelledException() : super('Stopped');
}
