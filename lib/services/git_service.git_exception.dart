part of 'git_service.dart';

/// A Git command that failed or couldn't be started.
///
/// Carries what git said, not how to tell the user: callers word the
/// failure with [explain].
class GitException implements Exception {
  /// The command line that failed, e.g. `git push`.
  final String command;

  /// Git's stderr or the underlying error; empty when there is none.
  final String details;

  /// Creates the failure of [command] with optional [details].
  const GitException(this.command, [this.details = '']);

  /// [action], the attempt as the caller words it (`Failed to push
  /// changes`), followed by the details when there are any.
  String explain(String action) {
    final trimmed = details.trim();
    return trimmed.isEmpty ? action : '$action: $trimmed';
  }

  @override
  String toString() => explain(command);
}
