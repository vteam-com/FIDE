import 'package:fide/models/creation_outcome.dart';
import 'package:fide/models/creation_step.dart';
import 'package:fide/models/loading_action.dart';

/// How a [CreationStep] of creating a project ended.
class CreationReport {
  /// The step that ended.
  final CreationStep step;

  /// How it ended.
  final CreationOutcome outcome;

  /// What goes with the outcome, such as the error of a failed step;
  /// empty when there is nothing.
  final String detail;

  /// Creates the report of [step] ending with [outcome].
  const CreationReport(this.step, this.outcome, {this.detail = ''});

  /// The step's status in the progress list.
  LoadingStatus get status => outcome.status;
}
