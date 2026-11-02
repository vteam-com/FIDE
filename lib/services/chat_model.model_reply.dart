part of 'chat_model.dart';

/// Cleans up the text a model replies with.
extension ModelReply on String {
  /// This text without the quotes or backticks a model wraps replies in.
  String get unquoted => replaceAll(RegExp(r'''^[`"']+|[`"']+$'''), '');
}
