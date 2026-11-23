import 'package:path/path.dart' as p;

/// The source changes that leave a Dart file with one public class: each
/// widget's `State` made private, and each other public class moved into a
/// file of its own.
class ClassSplitResult {
  /// Creates a result writing [files], of which [createdFiles] are new,
  /// having made [privatizedStates] private.
  const ClassSplitResult({
    required this.files,
    required this.createdFiles,
    this.privatizedStates = const [],
  });

  /// Paths in [files] that don't exist yet, in the order they were split.
  final List<String> createdFiles;

  /// New content of every file to write, keyed by absolute path.
  final Map<String, String> files;

  /// The widget `State`s made private, by the public name they had.
  final List<String> privatizedStates;

  /// What the split did, in one line: "Made FooState private; moved into
  /// bar.dart".
  String get summary => [
    if (privatizedStates.isNotEmpty)
      'Made ${privatizedStates.join(', ')} private',
    if (createdFiles.isNotEmpty)
      'Moved into ${createdFiles.map(p.basename).join(', ')}',
  ].join('; ');
}
