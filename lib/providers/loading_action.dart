part of 'app_providers.dart';

/// Represents `LoadingAction`.
class LoadingAction {
  final int step;
  final String text;
  LoadingStatus status;

  LoadingAction(this.step, this.text, this.status);
}
