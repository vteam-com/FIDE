import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_node.dart';

/// Defines the mutable project state surface used by `ProjectService`.
abstract class ProjectStateSink {
  /// Returns the current loading actions.
  List<LoadingAction> get loadingActions;

  /// Replaces the loading actions log.
  void replaceLoadingActions(List<LoadingAction> actions);

  /// Sets the current project path.
  void setCurrentProjectPath(String? path);

  /// Sets the current project root.
  void setCurrentProjectRoot(ProjectNode? root);

  /// Sets whether a project is currently loaded.
  void setProjectLoaded(bool isLoaded);

  /// Clears the currently selected file.
  void clearSelectedFile();

  /// Sets the latest project creation error message.
  void setProjectCreationError(String? message);
}
