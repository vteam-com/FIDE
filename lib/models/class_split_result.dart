import 'package:fide/models/locale_number.dart';
import 'package:path/path.dart' as p;

/// The source changes that leave a Dart file with one public class: each
/// widget's `State` moved beside it and made private, and each other
/// public class moved into a file of its own.
class ClassSplitResult {
  /// Creates a result writing [files], of which [createdFiles] are new,
  /// having moved [gatheredStates] beside their widget, emptying
  /// [mergedFiles], moved [movedOutOfStates] out of them, removed the
  /// statements reaching into them from [cleanedTests], and made
  /// [privatizedStates] private.
  const ClassSplitResult({
    required this.files,
    required this.createdFiles,
    this.gatheredStates = const [],
    this.mergedFiles = const {},
    this.cleanedTests = const {},
    this.movedOutOfStates = const {},
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

  /// How many statements reaching into a widget's `State`, which is
  /// private to its widget, were removed from each test file, by path.
  final Map<String, int> cleanedTests;

  /// The methods moved out of each widget `State`, by its name, as
  /// top-level functions the tests call directly: they used nothing of
  /// it.
  final Map<String, List<String>> movedOutOfStates;

  /// The widget `State`s made private, by the public name they had.
  final List<String> privatizedStates;

  /// What the split did, in one line: "Moved FooState beside its widget;
  /// Made BarState private; Moved into baz.dart".
  String get summary => [
    if (gatheredStates.isNotEmpty)
      'Moved ${gatheredStates.join(', ')} beside ${gatheredStates.length == 1 ? 'its widget' : 'their widgets'}',
    for (final MapEntry(key: state, value: methods) in movedOutOfStates.entries)
      'Moved ${methods.join(', ')} out of $state, for tests to call',
    if (cleanedTests.isNotEmpty)
      'Removed ${cleanedTests.values.fold(0, (sum, count) => sum + count).count('test statement')} reaching into them from ${cleanedTests.keys.map(p.basename).join(', ')}',
    if (privatizedStates.isNotEmpty)
      'Made ${privatizedStates.join(', ')} private',
    if (createdFiles.isNotEmpty)
      'Moved into ${createdFiles.map(p.basename).join(', ')}',
  ].join('; ');
}
