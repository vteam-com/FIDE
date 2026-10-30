/// Cuts text to a size limit.
extension TextTruncation on String {
  /// This text cut to [maxChars], with `...` marking the cut.
  String truncated(int maxChars) =>
      length > maxChars ? '${substring(0, maxChars)}...' : this;
}
