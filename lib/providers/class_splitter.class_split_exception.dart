part of 'class_splitter.dart';

/// Why a [ClassSplitter] plan was refused.
class ClassSplitException implements Exception {
  /// Creates an exception explained by [message].
  const ClassSplitException(this.message);

  /// What prevented the split, for the user.
  final String message;

  @override
  String toString() => message;
}
