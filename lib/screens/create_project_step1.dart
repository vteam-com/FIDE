import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class CreateProjectStep1 extends StatefulWidget {
  const CreateProjectStep1({
    super.key,
    required this.initialDirectory,
    required this.testInitialDirectory,
    required this.flutterStatusChecked,
    required this.flutterAvailable,
    required this.flutterVersion,
    required this.gitStatusChecked,
    required this.gitAvailable,
    required this.gitVersion,
    required this.ollamaStatusChecked,
    required this.ollamaAvailable,
    required this.onProjectNameChanged,
    required this.onDirectoryChanged,
    required this.onValidationChanged,
    required this.onUseAIChanged,
  });

  final bool flutterAvailable;

  final bool flutterStatusChecked;

  final String? flutterVersion;

  final bool gitAvailable;

  final bool gitStatusChecked;

  final String? gitVersion;

  final String? initialDirectory;

  final bool ollamaAvailable;

  final bool ollamaStatusChecked;

  final void Function(String directory) onDirectoryChanged;

  final void Function(String projectName, String? finalProjectName)
  onProjectNameChanged;

  final void Function(bool useAI) onUseAIChanged;

  final void Function(bool canProceed) onValidationChanged;

  final String? testInitialDirectory;

  @override
  State<CreateProjectStep1> createState() => _CreateProjectStep1State();
}

class _CreateProjectStep1State extends State<CreateProjectStep1> {
  String? _directory;

  String? _finalProjectName;

  bool _useAI = false;

  final TextEditingController descriptionController = TextEditingController();

  final TextEditingController directoryController = TextEditingController();

  final TextEditingController nameController = TextEditingController();

  String? selectedDirectory;

  @override
  void initState() {
    super.initState();
    nameController.addListener(_onProjectNameChanged);
    _initializeDirectoryController();
    // Defer notifying parent until after first build to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onUseAIChanged(_useAI);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    directoryController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 24,
      children: [
        // Step indicator
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Project Details'),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 2,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name',
            border: OutlineInputBorder(),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: directoryController,
                decoration: const InputDecoration(
                  labelText: 'Parent Directory',
                  hintText: 'Select parent directory',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _handleBrowseDirectory,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Browse'),
              ),
            ),
          ],
        ),

        // Show final project name if it's different from input
        if (_finalProjectName != null &&
            _finalProjectName != nameController.text)
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Row(
              spacing: 8,
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                Text(
                  'Project name will be: "$_finalProjectName"',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Flutter status
        if (widget.flutterStatusChecked)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(
                  widget.flutterAvailable ? Icons.check_circle : Icons.error,
                  color: widget.flutterAvailable ? Colors.green : Colors.red,
                  size: 16,
                ),
                Text(
                  widget.flutterAvailable
                      ? 'Flutter SDK: ${widget.flutterVersion}'
                      : 'Flutter SDK: Not Found',
                  style: TextStyle(
                    color: widget.flutterAvailable ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!widget.flutterAvailable) ...[
                  TextButton(
                    onPressed: () {
                      // Show installation instructions
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Install Flutter SDK'),
                            content: const SingleChildScrollView(
                              child: Text(
                                'Flutter SDK is not installed or not available in PATH.\n\n'
                                'To install Flutter:\n\n'
                                '1. Visit: https://flutter.dev/docs/get-started/install\n'
                                '2. Download the Flutter SDK for your platform\n'
                                '3. Extract the SDK to a location (e.g., ~/flutter)\n'
                                '4. Add the flutter/bin directory to your PATH:\n'
                                '   - macOS/Linux: Add to ~/.bashrc or ~/.zshrc:\n'
                                '     export PATH="\$PATH:~/flutter/bin"\n'
                                '   - Windows: Add to System Environment Variables\n'
                                '5. Run: flutter doctor\n\n'
                                'For detailed instructions, visit: https://flutter.dev/docs/get-started/install',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Install',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Git status
        if (widget.gitStatusChecked)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(
                  widget.gitAvailable ? Icons.check_circle : Icons.error,
                  color: widget.gitAvailable ? Colors.green : Colors.red,
                  size: 16,
                ),
                Text(
                  widget.gitAvailable
                      ? 'Git: ${widget.gitVersion}'
                      : 'Git: Not Found',
                  style: TextStyle(
                    color: widget.gitAvailable ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!widget.gitAvailable) ...[
                  TextButton(
                    onPressed: () {
                      // Show installation instructions
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Install Git'),
                            content: const SingleChildScrollView(
                              child: Text(
                                'Git is not installed or not available in PATH.\n\n'
                                'To install Git:\n\n'
                                '• macOS: Install Xcode Command Line Tools:\n'
                                '  xcode-select --install\n'
                                '  Or install Git from: https://git-scm.com/download/mac\n\n'
                                '• Linux (Ubuntu/Debian):\n'
                                '  sudo apt-get update && sudo apt-get install git\n\n'
                                '• Windows: Download from https://git-scm.com/download/win\n\n'
                                'For detailed instructions, visit: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Install',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // AI-powered generation toggle
        Row(
          children: [
            Expanded(
              child: Text(
                'Use AI-powered app generation (requires Ollama)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Switch(
              value: _useAI,
              onChanged: widget.ollamaStatusChecked && widget.ollamaAvailable
                  ? _onUseAIChanged
                  : null,
            ),
          ],
        ),

        // Description field only if AI is enabled AND Ollama is available
        if (_useAI && widget.ollamaStatusChecked && widget.ollamaAvailable)
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'App Description (AI-powered generation)',
              hintText: 'Describe what kind of app you want to create...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 2,
          ),
      ],
    );
  }

  void _handleBrowseDirectory() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null && mounted) {
      setState(() {
        selectedDirectory = selectedDir;
        directoryController.text = selectedDir;
        _directory = selectedDir;
      });
      widget.onDirectoryChanged(selectedDir);
      _updateValidation();
    }
  }

  Future<void> _initializeDirectoryController() async {
    final directoryPath =
        widget.testInitialDirectory ??
        widget.initialDirectory ??
        (await getApplicationDocumentsDirectory()).path;
    setState(() {
      directoryController.text = directoryPath;
      _directory = directoryPath;
    });
    widget.onDirectoryChanged(directoryPath);
    // Delay validation update until after widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateValidation();
    });
  }

  void _onProjectNameChanged() {
    final validatedName = _validateProjectName(nameController.text);
    if (_finalProjectName != validatedName) {
      setState(() {
        _finalProjectName = validatedName;
      });
      widget.onProjectNameChanged(nameController.text, validatedName);
      _updateValidation();
    }
  }

  void _onUseAIChanged(bool value) {
    setState(() {
      _useAI = value;
    });
    widget.onUseAIChanged(value);
  }

  void _updateValidation() {
    final canProceed =
        _finalProjectName != null &&
        _directory != null &&
        _directory!.isNotEmpty;
    widget.onValidationChanged(canProceed);
  }

  String? _validateProjectName(String inputName) {
    if (inputName.isEmpty) {
      return null;
    }

    // Only normalize if needed (spaces, special chars, etc.)
    String normalized = inputName;

    // Replace spaces and special characters with underscores
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    // Remove consecutive underscores
    normalized = normalized.replaceAll(RegExp(r'_+'), '_');

    // Remove leading/trailing underscores
    normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');

    // Ensure it doesn't start with a digit
    if (normalized.isNotEmpty && normalized.startsWith(RegExp(r'[0-9]'))) {
      normalized = 'app_$normalized';
    }

    // Ensure it's not empty after normalization
    if (normalized.isEmpty) {
      normalized = 'flutter_app';
    }

    // Check if it's a reserved Dart word and prefix if needed
    const reservedWords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
    };

    if (reservedWords.contains(normalized)) {
      normalized = '${normalized}_app';
    }

    return normalized;
  }
}
