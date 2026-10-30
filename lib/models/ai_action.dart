/// What the AI panel asks the model to do with the prompt.
enum AiAction {
  /// Free-form question, answered with the selected file as context.
  ask('Ask AI', 'Ask me anything about your code...'),

  /// Explain the pasted code.
  explain('Explain Code', 'Paste code here to get explanation...'),

  /// Generate code from a description.
  generate('Generate Code', 'Describe what code you want to generate...'),

  /// Refactor the pasted code.
  refactor('Refactor Code', 'Paste code and describe how to refactor it...'),

  /// Fix the errors of the last failed build, or the pasted ones.
  fixBuild(
    'Fix Build',
    'Send to fix the last failed build, or paste build errors...',
  ),

  /// Review the duplicate code fcheck finds in the project.
  dryReview(
    'D.R.Y. review',
    'Send to review duplicated code, or add what to focus on...',
  ),

  /// Review fcheck's largest and most coupled code against SOLID.
  solidReview(
    'S.O.L.I.D. review',
    'Send to review the design against SOLID, or add what to focus on...',
  );

  /// Menu label.
  final String label;

  /// Placeholder for the prompt field.
  final String hint;

  const AiAction(this.label, this.hint);

  /// Whether the action changes the project's files itself when a project
  /// is open and the model can call tools.
  bool get editsFiles =>
      this == ask || this == generate || this == refactor || this == fixBuild;

  /// Whether the action reviews the project from fcheck's analysis, which
  /// it sends as context so no prompt is needed.
  bool get isReview => this == dryReview || this == solidReview;
}
