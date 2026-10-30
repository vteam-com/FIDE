import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:path/path.dart' as p;

/// Prepares what the AI reviews read: fcheck's analysis of a project and
/// the code behind its findings, instead of the whole `lib` folder.
///
/// fcheck does the analysis; this class only picks the findings that
/// matter to a review and quotes their code.
class CodeReview {
  /// Creates a stateless review builder.
  const CodeReview();

  /// Analyzes the project at [projectPath] with fcheck, honoring its
  /// `.fcheck` file like the CLI, on a background isolate.
  ///
  /// [nearDuplicates] loosens duplicate detection to
  /// [AppMetric.aiReviewDuplicateSimilarity] so the review also sees code
  /// that was copied and has since drifted.
  Future<fcheck.ProjectMetrics> analyze(
    String projectPath, {
    bool nearDuplicates = false,
  }) => Isolate.run(
    () => fcheck.AnalyzeFolder.fromConfig(
      fcheck.FcheckConfig.loadForInputDirectory(Directory(projectPath)),
      duplicateCodeSimilarityThreshold: nearDuplicates
          ? AppMetric.aiReviewDuplicateSimilarity
          : null,
      duplicateCodeMinNonEmptyLineCount: nearDuplicates
          ? AppMetric.aiReviewDuplicateMinLines
          : null,
    ).analyze(),
  );

  /// The code that [metrics] shows is too big or too coupled for a SOLID
  /// review: the largest classes with their source, the files importing
  /// the most project files, and layer violations; cut to
  /// [AppMetric.aiReviewContextChars].
  Future<String> design(fcheck.ProjectMetrics metrics) async {
    final sources = _SourceReader(metrics.analysisRootPath);
    final classes = [...metrics.codeSizeClassArtifacts]
      ..sort((a, b) => b.linesOfCode.compareTo(a.linesOfCode));
    final largest = classes.take(AppMetric.aiReviewMaxItems).toList();
    final coupled = metrics.dependencyGraph.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final text = StringBuffer('## Largest classes\n');
    for (final artifact in largest) {
      text.writeln(
        '- `${artifact.name}` in ${sources.display(artifact.filePath)}:'
        '${artifact.startLine} (${artifact.linesOfCode} lines)',
      );
    }
    text.writeln('\n## Files importing the most project files');
    for (final entry in coupled.take(AppMetric.aiReviewMaxItems)) {
      text.writeln(
        '- ${sources.display(entry.key)}: ${entry.value.length} imports',
      );
    }
    if (metrics.layersIssues.isNotEmpty) {
      text.writeln('\n## Layer violations');
      for (final issue in metrics.layersIssues) {
        text.writeln('- $issue');
      }
    }
    text.writeln('\n## Source of the largest classes');
    for (final artifact in largest) {
      if (text.length >= AppMetric.aiReviewContextChars) break;
      final code = await sources.lines(
        artifact.filePath,
        artifact.startLine,
        endLine: artifact.endLine,
      );
      text.writeln(
        _codeBlock(
          '`${artifact.name}` in ${sources.display(artifact.filePath)}',
          code,
        ),
      );
    }
    return text.toString().truncated(AppMetric.aiReviewContextChars);
  }

  /// The duplicate code pairs in [metrics], most similar and longest
  /// first, each with both snippets, then the most repeated string
  /// literals; cut to [AppMetric.aiReviewContextChars].
  Future<String> duplicates(fcheck.ProjectMetrics metrics) async {
    final sources = _SourceReader(metrics.analysisRootPath);
    final pairs = [...metrics.duplicateCodeIssues]
      ..sort(
        (a, b) =>
            (b.similarity * b.lineCount).compareTo(a.similarity * a.lineCount),
      );
    final literals =
        metrics.stringLiteralFrequencies.entries
            .where((entry) => entry.value > 1 && _isWordLike(entry.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final text = StringBuffer(
      'fcheck found ${pairs.length} duplicate code pairs.\n',
    );
    for (final (index, pair) in pairs.indexed) {
      if (text.length >= AppMetric.aiReviewContextChars) break;
      text.writeln(
        '\n## ${index + 1}. ${pair.similarityPercentRoundedDown}% similar, '
        '${pair.lineCount} lines',
      );
      for (final (path, line, symbol) in [
        (pair.firstFilePath, pair.firstLineNumber, pair.firstSymbol),
        (pair.secondFilePath, pair.secondLineNumber, pair.secondSymbol),
      ]) {
        final code = await sources.lines(
          path,
          line,
          nonEmptyLines: pair.lineCount,
        );
        text.writeln(
          _codeBlock('`$symbol` in ${sources.display(path)}:$line', code),
        );
      }
    }
    if (literals.isNotEmpty) {
      text.writeln('\n## Most repeated string literals');
      for (final entry in literals.take(AppMetric.aiReviewMaxItems)) {
        text.writeln('- `${entry.key}` × ${entry.value}');
      }
    }
    return text.toString().truncated(AppMetric.aiReviewContextChars);
  }

  /// Whether [literal] is long enough and has a letter, so separators and
  /// punctuation don't crowd out the literals worth a shared constant.
  bool _isWordLike(String literal) =>
      literal.length >= AppMetric.aiReviewMinLiteralChars &&
      literal.contains(RegExp('[A-Za-z]'));

  /// [code] in a fenced Dart block under the [title] line.
  String _codeBlock(String title, String code) => '$title\n```dart\n$code\n```';
}

/// Reads and labels the source files fcheck's findings point to; paths
/// may be absolute or relative to the analysis root.
class _SourceReader {
  /// The folder fcheck analyzed.
  final String _root;

  /// File lines already read, by absolute path.
  final Map<String, List<String>> _cache = {};

  /// Creates a reader for findings under [_root].
  _SourceReader(this._root);

  /// [path] relative to the analysis root, for display.
  String display(String path) => p.relative(_absolute(path), from: _root);

  /// The lines of [path] from 1-based [startLine]: through [endLine], or
  /// until [nonEmptyLines] non-empty lines are taken; empty when the file
  /// can't be read.
  Future<String> lines(
    String path,
    int startLine, {
    int? endLine,
    int? nonEmptyLines,
  }) async {
    final absolute = _absolute(path);
    final List<String> all;
    try {
      all = _cache[absolute] ??= await File(absolute).readAsLines();
    } on FileSystemException {
      return '';
    }
    final taken = <String>[];
    var nonEmpty = 0;
    for (var i = startLine - 1; i < all.length; i++) {
      if (endLine != null && i >= endLine) break;
      if (nonEmptyLines != null && nonEmpty >= nonEmptyLines) break;
      taken.add(all[i]);
      if (all[i].trim().isNotEmpty) nonEmpty++;
    }
    return taken.join('\n');
  }

  /// [path] made absolute against the analysis root.
  String _absolute(String path) =>
      p.isAbsolute(path) ? path : p.join(_root, path);
}
