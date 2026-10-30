import 'package:fide/models/app_theme.dart';
import 'package:flutter/material.dart';

/// Progress of a panel action (build, run, test...).
enum ActionStatus {
  /// Not started, or back to rest after showing a result.
  idle,

  /// In progress.
  running,

  /// Finished successfully.
  success,

  /// Failed or exited non-zero.
  error,
}

/// How a finished [ActionStatus] is drawn, shared by every action list so
/// success and failure look the same everywhere.
extension ActionStatusResult on ActionStatus {
  /// A check for [ActionStatus.success], an error mark for
  /// [ActionStatus.error]; null while idle or running.
  IconData? get resultIcon => switch (this) {
    ActionStatus.success => Icons.check_circle,
    ActionStatus.error => Icons.error,
    _ => null,
  };

  /// The semantic color of [resultIcon]; null while idle or running.
  Color? get resultColor => switch (this) {
    ActionStatus.success => AppTheme.successColor,
    ActionStatus.error => AppTheme.errorColor,
    _ => null,
  };

  /// A one-word name of the result; null while idle or running.
  String? get resultLabel => switch (this) {
    ActionStatus.success => 'Success',
    ActionStatus.error => 'Failed',
    _ => null,
  };
}
