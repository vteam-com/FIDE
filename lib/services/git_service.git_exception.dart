part of 'git_service.dart';

/// A Git operation that failed.
class GitException implements Exception {
  /// What was being attempted, e.g. `Failed to push changes`.
  final String message;

  /// Git's stderr or the underlying error; empty when there is none.
  final String details;

  /// Creates a failure for [message] with optional [details].
  const GitException(this.message, [this.details = '']);

  @override
  String toString() {
    final trimmed = details.trim();
    return trimmed.isEmpty ? message : '$message: $trimmed';
  }
}
