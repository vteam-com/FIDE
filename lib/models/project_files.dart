import 'package:fide/models/project_node.dart';
import 'package:path/path.dart' as p;

/// The files of a project the user works on, leaving out tool output and
/// hidden folders and files.
class ProjectFiles {
  /// Folders left out besides hidden ones: tool output, installed
  /// dependencies and Git data.
  static const Set<String> skippedFolders = {
    'build',
    '.dart_tool',
    '.git',
    'node_modules',
    'Pods',
  };

  /// Whether a folder or file named [name] is left out.
  static bool isSkipped(String name) =>
      skippedFolders.contains(name) || name.startsWith('.');

  /// Whether [relativePath] lies in, or is, an entry that is left out.
  static bool isSkippedPath(String relativePath) =>
      p.split(relativePath).any(isSkipped);

  /// Paths of the files in the loaded tree under [root], in tree order.
  static List<String> under(ProjectNode root) {
    final files = <String>[];
    void collect(ProjectNode node) {
      for (final child in node.uniqueChildren) {
        if (isSkipped(child.name)) continue;
        if (child.isDirectory) {
          collect(child);
        } else {
          files.add(child.path);
        }
      }
    }

    collect(root);
    return files;
  }
}
