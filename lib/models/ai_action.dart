part 'ai_action.ai_context.dart';

/// What the AI panel asks the model to do with the prompt: each action
/// says what it sends with the prompt, how the model is told to handle
/// it and whether the agent edits the files, so a new action is one entry.
enum AiAction {
  /// Free-form question, answered with the selected file as context.
  ask(
    'Ask AI',
    'Ask me anything about your code...',
    editsFiles: true,
    context: AiContext.selectedFile,
  ),

  /// Explain the pasted code.
  explain(
    'Explain Code',
    'Paste code here to get explanation...',
    instruction: 'Explain what this code does in simple terms:',
  ),

  /// Generate code from a description.
  generate(
    'Generate Code',
    'Describe what code you want to generate...',
    editsFiles: true,
    instruction: 'Generate Flutter/Dart code for the following requirement:',
  ),

  /// Refactor the pasted code.
  refactor(
    'Refactor Code',
    'Paste code and describe how to refactor it...',
    editsFiles: true,
    instruction:
        'Refactor this code with the following instruction: Please '
        'refactor this code',
  ),

  /// Fix the errors of the last failed build, or the pasted ones; a
  /// thinking model reasons first, as tracing errors to their cause needs
  /// it.
  fixBuild(
    'Fix Build',
    'Send to fix the last failed build, or paste build errors...',
    editsFiles: true,
    think: true,
    context: AiContext.buildErrors,
    instruction:
        'This Flutter/Dart build failed. Find the root cause of each error '
        'and show the code changes that fix it, naming the file each '
        'change belongs to.',
  ),

  /// Review the duplicate code fcheck finds in the project.
  dryReview(
    'D.R.Y. review',
    'Send to review duplicated code, or add what to focus on...',
    think: true,
    context: AiContext.duplicates,
    instruction:
        'Below are the duplicate code pairs and repeated string literals '
        'fcheck found. Decide which are real duplication worth removing; '
        'for each, name the files involved and the shared helper, widget '
        'or constant to extract.',
  ),

  /// Review fcheck's largest and most coupled code against SOLID.
  solidReview(
    'S.O.L.I.D. review',
    'Send to review the design against SOLID, or add what to focus on...',
    think: true,
    context: AiContext.design,
    instruction:
        'Below are the largest classes, the most coupled files and the '
        'layer violations fcheck found, with the source of the largest '
        'classes. Check them against the SOLID principles: single '
        'responsibility, open/closed, Liskov substitution, interface '
        'segregation and dependency inversion. For each violation, name '
        'the principle, the file and class, and the change that fixes it.',
  );

  /// Menu label.
  final String label;

  /// Placeholder for the prompt field.
  final String hint;

  /// Whether the action changes the project's files itself when a project
  /// is open and the model can call tools.
  final bool editsFiles;

  /// Whether a thinking model reasons before answering, for actions
  /// needing judgment.
  final bool think;

  /// What is sent with the prompt; with [AiContext.none] the prompt itself
  /// is the code or description the [instruction] applies to.
  final AiContext context;

  /// What the model is told to do; empty when the prompt says it.
  final String instruction;

  const AiAction(
    this.label,
    this.hint, {
    this.editsFiles = false,
    this.think = false,
    this.context = AiContext.none,
    this.instruction = '',
  });

  /// Whether the action reviews the project from fcheck's analysis, which
  /// it sends as context so no prompt is needed.
  bool get isReview => context.isReview;
}
