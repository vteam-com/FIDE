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
  );

  /// Menu label.
  final String label;

  /// Placeholder for the prompt field.
  final String hint;

  const AiAction(this.label, this.hint);
}
