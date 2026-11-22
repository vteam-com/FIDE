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

  /// The repository path the file moved from, when git pairs it with a
  /// deleted file alike as one renamed: [added] and [removed] then count
  /// the lines changed between the two. Null for a file that didn't move.
  final String? movedFrom;

  /// Creates the stats of a file.
  GitDiffStats({
    required this.added,
    required this.removed,
    required this.isNewFile,
    this.isBinary = false,
    this.movedFrom,
  });

  /// Tab-separated fields of a `git diff --numstat` line: added, removed,
  /// path.
  static const int _numstatFields = 3;

  /// The count `git diff --numstat` prints for a binary file.
  static const String _binaryCount = '-';

  /// Records that follow the counts of a rename in `-z` output: its old
  /// path, then its new one.
  static const int _renamePaths = 2;

  /// Whether the file changed: lines added or removed, or binary content
  /// rewritten.
  bool get hasChanges => added > 0 || removed > 0 || isBinary;

  /// Whether the file may be gone: a deletion counts lines removed and
  /// none added, or a binary file changed, as a file emptied does too.
  bool get mayBeGone => added == 0 && (removed > 0 || isBinary);

  /// Line counts per file of `git diff --numstat` [output], keyed by the
  /// path git printed; binary files (`-` counts) are [isBinary] with zero
  /// lines and lines of another shape are skipped. Records end with
  /// [recordSeparator]: a NUL for `-z` output, whose paths aren't quoted
  /// and where a rename leaves its path empty, its old and new paths
  /// following as records of their own: it is keyed by the new path,
  /// [movedFrom] the old.
  static Map<String, GitDiffStats> parseNumstat(
    String output, {
    String recordSeparator = '\n',
  }) {
    final stats = <String, GitDiffStats>{};
    final records = output.split(recordSeparator);
    for (var i = 0; i < records.length; i++) {
      final fields = records[i].split('\t');
      if (fields.length < _numstatFields) continue;
      // A path may itself hold tabs
      var path = fields.skip(_numstatFields - 1).join('\t');
      String? movedFrom;
      if (path.isEmpty) {
        if (i + _renamePaths >= records.length) break;
        movedFrom = records[++i];
        path = records[++i];
      }
      stats[path] = GitDiffStats(
        added: int.tryParse(fields[0]) ?? 0,
        removed: int.tryParse(fields[1]) ?? 0,
        isNewFile: false,
        isBinary: fields[0] == _binaryCount,
        movedFrom: movedFrom,
      );
    }
    return stats;
  }
}
