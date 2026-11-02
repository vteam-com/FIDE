part of 'chat_model.dart';

/// A request to the local model stopped by [AiCancelToken.cancel].
class AiCancelledException extends AiServiceException {
  /// Creates the failure of a cancelled request.
  const AiCancelledException() : super('Stopped');
}
