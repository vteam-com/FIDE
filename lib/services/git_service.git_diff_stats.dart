part of 'git_service.dart';

/// Represents `GitDiffStats`.
class GitDiffStats {
  final int added;
  final int removed;
  final bool isNewFile;

  GitDiffStats({
    required this.added,
    required this.removed,
    required this.isNewFile,
  });

  /// Tab-separated fields of a `git diff --numstat` line: added, removed,
  /// path.
  static const int _numstatFields = 3;

  /// Whether this diff stat contains any additions or removals.
  bool get hasChanges => added > 0 || removed > 0;

  /// Line counts per file of `git diff --numstat` [output], keyed by the
  /// path git printed; binary files (`-` counts) count as zero lines and
  /// lines of another shape are skipped.
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
      );
    }
    return stats;
  }
}
