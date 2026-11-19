/// Cuts text to a size limit.
extension TextTruncation on String {
  /// This text cut to [maxChars], with `…` marking the cut.
  String truncated(int maxChars) =>
      length > maxChars ? '${substring(0, maxChars)}…' : this;

  /// This text cut to its last [maxChars], with `…` marking the cut: for
  /// command output, which ends with how the command went.
  String truncatedStart(int maxChars) =>
      length > maxChars ? '…${substring(length - maxChars)}' : this;
}
