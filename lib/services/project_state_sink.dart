import 'package:fide/models/project_node.dart';

/// Defines the mutable project state surface used by `ProjectService`.
abstract class ProjectStateSink {
  /// Sets the current project path.
  void setCurrentProjectPath(String? path);

  /// Sets the current project root.
  void setCurrentProjectRoot(ProjectNode? root);

  /// Signals that the current project tree was updated in place.
  void bumpProjectTreeRevision();

  /// Sets whether a project is currently loaded.
  void setProjectLoaded(bool isLoaded);

  /// Clears the currently selected file.
  void clearSelectedFile();
}
