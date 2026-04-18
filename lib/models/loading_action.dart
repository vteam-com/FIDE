/// Represents the lifecycle state of a loading action.
enum LoadingStatus { pending, success, failed }

/// Represents a single step in the project loading workflow.
class LoadingAction {
  final int step;
  final String text;
  LoadingStatus status;

  /// Creates a loading action entry.
  LoadingAction(this.step, this.text, this.status);
}
