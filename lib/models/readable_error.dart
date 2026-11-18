import 'dart:io';

/// Turns an error into a sentence people can read, for a viewer that
/// can't open or save its file.
class ReadableError {
  const ReadableError._();

  /// What `toString` puts before the message of a plain [Exception] and
  /// of a [StateError], in the order a relayed error nests them.
  static const List<String> _typePrefixes = ['Exception: ', 'Bad state: '];

  /// What went wrong in [error]: its message, without the exception's
  /// type name.
  static String describe(Object error) => switch (error) {
    ProcessException(:final message) => message,
    HttpException(:final message) || SocketException(:final message) => message,
    FormatException(:final message) => message,
    FileSystemException(:final message, :final path) => '$message: $path',
    StateError(:final message) => message,
    _ => _withoutTypePrefixes('$error'),
  };

  /// [text] without the [_typePrefixes] it starts with.
  static String _withoutTypePrefixes(String text) {
    var message = text;
    for (final prefix in _typePrefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
      }
    }
    return message;
  }
}
