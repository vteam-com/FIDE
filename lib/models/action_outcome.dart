import 'package:fide/models/status_tone.dart';

/// How a panel action ended: the message to show the user, in the tone
/// of its meaning.
class ActionOutcome {
  /// What to tell the user.
  final String message;

  /// The meaning of [message]: success, failure or plain information.
  final StatusTone tone;

  /// The action failed with [message].
  const ActionOutcome.failure(this.message) : tone = StatusTone.error;

  /// The action ended with nothing done, explained by [message].
  const ActionOutcome.info(this.message) : tone = StatusTone.info;

  /// The action succeeded with [message].
  const ActionOutcome.success(this.message) : tone = StatusTone.success;

  /// Whether the action succeeded.
  bool get succeeded => tone == StatusTone.success;
}
