/// How a Localization panel action ended, as the message to show the user.
class LocalizationOutcome {
  /// Whether the action succeeded.
  final bool succeeded;

  /// What to tell the user.
  final String message;

  /// The action succeeded with [message].
  const LocalizationOutcome.success(this.message) : succeeded = true;

  /// The action failed with [message].
  const LocalizationOutcome.failure(this.message) : succeeded = false;
}
