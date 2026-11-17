part of 'git_service.dart';

/// Where a folder sits in its Git repository.
class GitRepoLocation {
  /// Creates the location of a folder [prefix] below the repository
  /// [root].
  const GitRepoLocation({required this.root, required this.prefix});

  /// Absolute path of the repository's top folder, as git prints it.
  final String root;

  /// The folder's path relative to [root] with a trailing slash, as
  /// `git rev-parse --show-prefix` prints it; empty for [root] itself.
  final String prefix;

  /// The repository path of the file named [fileName] in the folder.
  String pathOf(String fileName) => '$prefix$fileName';
}
