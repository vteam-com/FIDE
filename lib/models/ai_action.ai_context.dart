part of 'ai_action.dart';

/// What an [AiAction] sends the model along with the user's prompt.
enum AiContext {
  /// Nothing: the prompt is the code or description to work on.
  none,

  /// The content of the file open in the editor.
  selectedFile,

  /// The error output of the last failed build.
  buildErrors,

  /// fcheck's duplicate code and repeated literals, with their code.
  duplicates(isReview: true),

  /// fcheck's largest and most coupled code, with its source.
  design(isReview: true);

  const AiContext({this.isReview = false});

  /// Whether the context is fcheck's analysis of the project, which the
  /// model reviews.
  final bool isReview;
}
