/// Where the local Ollama setup stands: the first missing piece, an
/// install step in progress, or ready.
enum OllamaStep {
  /// The `ollama` executable is missing.
  notInstalled(
    'Ollama is not installed.',
    'Install Ollama',
    'Error installing Ollama',
  ),

  /// Ollama is installed but its server does not answer.
  notRunning(
    'Ollama is installed but not running.',
    'Run Ollama',
    'Error starting Ollama',
  ),

  /// The server runs but no usable model is downloaded.
  noModel(
    'Ollama is running but no model is downloaded.',
    'Download Model',
    'Error downloading model',
  ),

  /// An install, start or download is in progress.
  installing('Setting up Ollama…'),

  /// Ollama and a model are ready.
  ready('Ollama is ready to use!');

  const OllamaStep(this.message, [this.actionLabel, this.errorPrefix]);

  /// What the setup card says at this step.
  final String message;

  /// Label of the button that fixes this step; null when there is nothing
  /// to do.
  final String? actionLabel;

  /// Start of the message shown when fixing this step fails.
  final String? errorPrefix;
}
