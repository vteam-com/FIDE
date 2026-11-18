part of 'reference_finder.dart';

/// A question [ReferenceFinder] sends its background isolate, answered
/// with a [T]. Sealed, so the worker handles every kind of request.
sealed class ReferenceRequest<T> {
  /// Creates a request; it is sent to the worker isolate as is.
  const ReferenceRequest();

  /// Whether only the latest request of its kind is worth answering, such
  /// as a lookup for the declaration under the cursor: one a newer one of
  /// its kind replaced while it waited answers [ReferenceFinder.superseded].
  bool get isLatestOnly => false;

  /// [answer], the worker's reply to this request, as its type.
  T answerFrom(Object? answer) => answer as T;
}
