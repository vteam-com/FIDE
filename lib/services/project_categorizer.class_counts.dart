part of 'project_categorizer.dart';

/// Class counts of each Dart file, read from fCheck's analysis of the
/// project rather than worked out again.
class _ClassCounts {
  /// Indexes [code]'s files; empty without it.
  _ClassCounts(fcheck.ProjectMetrics? code) {
    for (final metrics in code?.fileMetrics ?? const <fcheck.FileMetrics>[]) {
      _metrics[p.normalize(metrics.path)] = metrics;
    }
    for (final artifact
        in code?.codeSizeArtifacts ?? const <fcheck.CodeSizeArtifact>[]) {
      if (artifact.kind != fcheck.CodeSizeArtifactKind.classDeclaration) {
        continue;
      }
      _declared.update(
        p.normalize(artifact.filePath),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  /// A Dart file counts as one class even when it declares none.
  static const int minPerFile = 1;

  /// fCheck's metrics of each file, by normalized path.
  final Map<String, fcheck.FileMetrics> _metrics = {};

  /// How many classes, private ones included, each file declares, by
  /// normalized path.
  final Map<String, int> _declared = {};

  /// How many classes, private ones included, [filePath] declares; its
  /// public ones when fCheck's code size analysis is turned off.
  int declaredIn(String filePath) {
    final path = p.normalize(filePath);
    return _declared[path] ?? _metrics[path]?.classCount ?? 0;
  }

  /// How many public classes [filePath] declares when it breaks fCheck's
  /// one class per file rule; null when it follows it or wasn't analyzed.
  int? breakingRuleIn(String filePath) {
    final metrics = _metrics[p.normalize(filePath)];
    if (metrics == null || metrics.isOneClassPerFileCompliant) return null;
    return metrics.classCount;
  }
}
