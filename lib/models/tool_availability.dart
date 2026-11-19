/// Which of the tools a new project uses are installed: Flutter and Git
/// with their versions. Ollama, for AI generation, is the AI panel's
/// `ollamaStatusProvider`.
class ToolAvailability {
  /// Creates the availability of each tool; a null [gitVersion] means Git
  /// wasn't found.
  const ToolAvailability({
    required this.flutterAvailable,
    this.flutterVersion,
    this.gitVersion,
  });

  /// Whether `flutter` runs.
  final bool flutterAvailable;

  /// Installed Flutter version; null when Flutter isn't installed.
  final String? flutterVersion;

  /// Installed Git version; null when Git isn't installed.
  final String? gitVersion;

  /// Whether `git` runs.
  bool get gitAvailable => gitVersion != null;
}
