part of 'git_service.dart';

/// How a file changed since HEAD: its added and removed line counts, or
/// for a binary file such as an image just that it changed.
class GitDiffStats {
  /// Lines added; zero for a binary file.
  final int added;

  /// Lines removed; zero for a binary file.
  final int removed;

  /// Whether the file isn't in HEAD at all.
  final bool isNewFile;

  /// Whether the file is binary, changed without countable lines.
  final bool isBinary;

  /// Creates the stats of a file.
  GitDiffStats({
    required this.added,
    required this.removed,
    required this.isNewFile,
    this.isBinary = false,
  });

  /// Tab-separated fields of a `git diff --numstat` line: added, removed,
  /// path.
  static const int _numstatFields = 3;

  /// The count `git diff --numstat` prints for a binary file.
  static const String _binaryCount = '-';

  /// Whether the file changed: lines added or removed, or binary content
  /// rewritten.
  bool get hasChanges => added > 0 || removed > 0 || isBinary;

  /// Line counts per file of `git diff --numstat` [output], keyed by the
  /// path git printed; binary files (`-` counts) are [isBinary] with zero
  /// lines and lines of another shape are skipped.
  static Map<String, GitDiffStats> parseNumstat(String output) {
    final stats = <String, GitDiffStats>{};
    for (final line in output.split('\n')) {
      final fields = line.split('\t');
      if (fields.length < _numstatFields) continue;
      // A path may itself hold tabs
      stats[fields.skip(_numstatFields - 1).join('\t')] = GitDiffStats(
        added: int.tryParse(fields[0]) ?? 0,
        removed: int.tryParse(fields[1]) ?? 0,
        isNewFile: false,
        isBinary: fields[0] == _binaryCount,
      );
    }
    return stats;
  }
}
