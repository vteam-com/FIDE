part of 'git_service.dart';

/// Represents `GitCommit`.
class GitCommit {
  final String hash;
  final String message;

  GitCommit({required this.hash, required this.message});
}
