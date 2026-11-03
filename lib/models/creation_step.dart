/// A step of creating a project, in the order they run.
enum CreationStep {
  /// Checking the settings and the tools creation needs.
  validate,

  /// `flutter create`.
  flutterCreate,

  /// Setting up localization and the chosen languages.
  localization,

  /// Generating the starter code, with AI when asked.
  codegen,

  /// Initializing the Git repository.
  gitInit,

  /// Checking the created project is complete.
  verification;

  /// Number of the first step, as the progress list counts them.
  static const int _firstNumber = 1;

  /// The step's number in the progress list, counted from one.
  int get number => index + _firstNumber;
}
