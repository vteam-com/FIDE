/// Cleans up the text a model replies with.
extension ModelReply on String {
  /// The quotes or backticks a model wraps a reply in, at either end.
  static final RegExp _wrappingQuotes = RegExp(r'''^[`"']+|[`"']+$''');

  /// This text without the quotes or backticks a model wraps replies in.
  String get unquoted => replaceAll(_wrappingQuotes, '');
}
