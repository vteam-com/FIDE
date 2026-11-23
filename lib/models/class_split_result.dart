import 'package:path/path.dart' as p;

/// The source changes that leave a Dart file with one public class: each
/// widget's `State` moved beside it and made private, and each other
/// public class moved into a file of its own.
class ClassSplitResult {
  /// Creates a result writing [files], of which [createdFiles] are new,
  /// having moved [gatheredStates] beside their widget, emptying
  /// [mergedFiles], and made [privatizedStates] private.
  const ClassSplitResult({
    required this.files,
    required this.createdFiles,
    this.gatheredStates = const [],
    this.mergedFiles = const {},
    this.privatizedStates = const [],
  });

  /// Paths in [files] that don't exist yet, in the order they were split.
  final List<String> createdFiles;

  /// New content of every file to write, keyed by absolute path.
  final Map<String, String> files;

  /// The widget `State`s moved from a part file beside their widget, by
  /// name.
  final List<String> gatheredStates;

  /// The part files emptied by moving their `State`s out, to delete, each
  /// by the file in [files] that took in what it held.
  final Map<String, String> mergedFiles;

  /// The widget `State`s made private, by the public name they had.
  final List<String> privatizedStates;

  /// What the split did, in one line: "Moved FooState beside its widget;
  /// Made BarState private; Moved into baz.dart".
  String get summary => [
    if (gatheredStates.isNotEmpty)
      'Moved ${gatheredStates.join(', ')} beside ${gatheredStates.length == 1 ? 'its widget' : 'their widgets'}',
    if (privatizedStates.isNotEmpty)
      'Made ${privatizedStates.join(', ')} private',
    if (createdFiles.isNotEmpty)
      'Moved into ${createdFiles.map(p.basename).join(', ')}',
  ].join('; ');
}
