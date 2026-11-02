part of 'git_service.dart';

/// Represents `GitCommit`.
class GitCommit {
  final String hash;
  final String message;

  /// When the commit was made (committer date).
  final DateTime date;

  /// Whether the commit is still only local: the upstream branch lacks it.
  final bool isUnpushed;

  GitCommit({
    required this.hash,
    required this.message,
    required this.date,
    this.isUnpushed = false,
  });
}
