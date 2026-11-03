part of 'git_service.dart';

/// One entry of `git status --porcelain`: its two-letter status [code] and
/// the [path] the change lives at.
typedef GitStatusEntry = ({String code, String path});

/// Parsers of Git's machine-readable output: text in, models out, with
/// no process or disk access, so they are tested from strings.
abstract final class GitPorcelain {
  /// Fields of `git rev-list --left-right --count`: ahead, then behind.
  static const int _syncCountFields = 2;

  /// Tab-separated fields of a `git log` line as [parseCommit] reads it:
  /// hash, time, subject.
  static const int _commitFields = 3;

  /// Porcelain separator between the old and new path of a rename or copy.
  static const String _renameArrow = ' -> ';

  /// Porcelain status letter of an untracked file.
  static const String _untrackedLetter = '?';

  /// Porcelain status letter of an unchanged side.
  static const String _unchangedLetter = ' ';

  /// What `git --version` prints before the version number.
  static final RegExp _versionPattern = RegExp(r'git version (\d+\.\d+\.\d+)');

  /// The entries of `git status --porcelain` [output]; a rename or copy
  /// lists `old -> new` and is reported at the new path, and a wholly new
  /// directory keeps its trailing slash, as git prints it.
  static List<GitStatusEntry> parseStatus(String output) {
    final entries = <GitStatusEntry>[];
    for (final line in output.split('\n')) {
      if (line.length < AppMetric.gitStatusFieldOffset) continue;
      final code = line.substring(0, AppMetric.doubleLineLimit);
      final entryPath = line.substring(AppMetric.gitStatusFieldOffset);
      entries.add((
        code: code,
        path: entryPath.contains(_renameArrow)
            ? entryPath.split(_renameArrow).last
            : entryPath,
      ));
    }
    return entries;
  }

  /// Files the porcelain entry for [file] with two-letter [code] into the
  /// staged, unstaged and untracked lists of [into].
  static void classify(String code, String file, GitStatus into) {
    if (code[0] == _untrackedLetter) {
      into.untracked.add(file);
      return;
    }
    if (code[0] != _unchangedLetter) {
      into.staged.add(file);
      into.stagedKinds[file] = kindOf(code[0]);
    }
    if (code[1] != _unchangedLetter) {
      into.unstaged.add(file);
      into.unstagedKinds[file] = kindOf(code[1]);
    }
  }

  /// The change a porcelain status [letter] stands for: added, deleted, or
  /// modified for everything else (edits, renames, type changes,
  /// conflicts).
  static GitFileStatus kindOf(String letter) => switch (letter) {
    'A' => GitFileStatus.added,
    'D' => GitFileStatus.deleted,
    _ => GitFileStatus.modified,
  };

  /// Parses a `hash<TAB>unix time<TAB>subject` log [line], flagging the
  /// commit unpushed when [unpushed] holds its hash; null when the line
  /// doesn't have that shape.
  static GitCommit? parseCommit(String line, Set<String> unpushed) {
    final fields = line.split('\t');
    if (fields.length < _commitFields) return null;
    final seconds = int.tryParse(fields[1]);
    if (seconds == null) return null;
    final hash = fields.first;
    return GitCommit(
      hash: hash,
      // A subject may itself hold tabs
      message: fields.skip(_commitFields - 1).join('\t'),
      date: DateTime.fromMillisecondsSinceEpoch(
        seconds * Duration.millisecondsPerSecond,
      ),
      isUnpushed: unpushed.contains(hash),
    );
  }

  /// The ahead and behind counts of `git rev-list --left-right --count`
  /// [output]; both zero when it doesn't hold two numbers, as for a branch
  /// without upstream.
  static ({int ahead, int behind}) parseSyncCounts(String? output) {
    final counts = output?.trim().split(RegExp(r'\s+'));
    if (counts == null || counts.length != _syncCountFields) {
      return (ahead: 0, behind: 0);
    }
    return (
      ahead: int.tryParse(counts.first) ?? 0,
      behind: int.tryParse(counts.last) ?? 0,
    );
  }

  /// The version number in `git --version` [output], e.g. `2.39.3`; null
  /// when the output doesn't hold one.
  static String? parseVersion(String output) =>
      _versionPattern.firstMatch(output)?.group(1);
}
