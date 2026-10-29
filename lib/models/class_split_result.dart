/// The source changes that leave a Dart file with one public class, moving
/// each other public class into a file of its own.
class ClassSplitResult {
  /// Creates a result writing [files], of which [createdFiles] are new.
  const ClassSplitResult({required this.files, required this.createdFiles});

  /// Paths in [files] that don't exist yet, in the order they were split.
  final List<String> createdFiles;

  /// New content of every file to write, keyed by absolute path.
  final Map<String, String> files;
}
