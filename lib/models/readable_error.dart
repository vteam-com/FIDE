import 'dart:io';

/// Turns an error into a sentence people can read, for a viewer that
/// can't open or save its file.
class ReadableError {
  const ReadableError._();

  /// What went wrong in [error]: its message, without the exception's
  /// type name.
  static String describe(Object error) => switch (error) {
    ProcessException(:final message) => message,
    FormatException(:final message) => message,
    FileSystemException(:final message, :final path) => '$message: $path',
    _ => '$error',
  };
}
